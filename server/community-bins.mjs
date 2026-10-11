import { createHash } from 'node:crypto';
import { ClientError } from './policy.mjs';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MATERIALS = ['Paper', 'Cardboard', 'Plastic', 'Metal', 'Glass', 'Other', 'Unknown'];
const digest = value => createHash('sha256').update(value).digest('hex');
const fail = message => { throw new ClientError(message); };
export function metres(a,b) {
  const r = Math.PI / 180, dlat = (a.latitude - b.latitude) * r, dlon = (a.longitude - b.longitude) * r;
  return 6371000 * 2 * Math.asin(Math.min(1,Math.sqrt(Math.sin(dlat / 2) ** 2 + Math.cos(a.latitude * r) * Math.cos(b.latitude * r) * Math.sin(dlon / 2) ** 2)));
}
// Keep compressed pixels; remove EXIF, comments and application metadata before storage.
// Parse markers rather than searching bytes inside the entropy-coded image stream.
export function cleanJPEG(data) {
  if (typeof data !== 'string' || data.length > 500000 || data.length < 100 || data.length % 4 || !/^[A-Za-z0-9+/]+={0,2}$/.test(data)) fail('Use a JPEG photo under 375 KB.');
  const bytes = Buffer.from(data,'base64');
  if (bytes.toString('base64') !== data || bytes[0] !== 255 || bytes[1] !== 216) fail('Invalid JPEG photo.');
  const parts = [bytes.subarray(0,2)]; let p = 2, frame = false, scan = false;
  while (p < bytes.length) {
    const start = p;
    if (bytes[p++] !== 255) fail('Invalid JPEG markers.');
    while (bytes[p] === 255) p++;
    const marker = bytes[p++];
    if (marker === 217) {
      if (!frame || !scan || p !== bytes.length) fail('Incomplete JPEG photo.');
      parts.push(bytes.subarray(start,p)); return Buffer.concat(parts);
    }
    if (marker === 0 || marker === 216 || (marker >= 208 && marker <= 215) || marker === 1 || p + 2 > bytes.length) fail('Invalid JPEG photo.');
    const length = bytes.readUInt16BE(p), end = p + length;
    if (length < 2 || end > bytes.length) fail('Incomplete JPEG photo.');
    if ([192,193,194].includes(marker)) {
      if (length < 8) fail('Invalid JPEG dimensions.');
      const height = bytes.readUInt16BE(p + 3), width = bytes.readUInt16BE(p + 5);
      if (!height || !width || height > 1600 || width > 1600) fail('Resize the photo to at most 1600 pixels.');
      frame = true;
    }
    if (!(marker >= 224 && marker <= 239) && marker !== 254) parts.push(bytes.subarray(start,end));
    p = end;
    if (marker === 218) {
      scan = true; const scanStart = p;
      while (p < bytes.length) {
        if (bytes[p] !== 255) { p++; continue; }
        const next = bytes[p + 1];
        if (next === 0 || (next >= 208 && next <= 215)) { p += 2; continue; }
        break;
      }
      parts.push(bytes.subarray(scanStart,p));
    }
  }
  fail('Incomplete JPEG photo.');
}
function submission(body,now) {
  if (!body || !UUID.test(body.id)) fail('Missing bin ID.');
  const name = typeof body.name === 'string' ? body.name.trim() : '', notes = typeof body.notes === 'string' ? body.notes.trim() : '';
  if (name.length < 2 || name.length > 80 || notes.length > 500) fail('Add a bin name (2–80 characters) and notes under 500 characters.');
  const c = body.coordinate;
  if (!c || !Number.isFinite(c.latitude) || !Number.isFinite(c.longitude) || Math.abs(c.latitude) > 90 || Math.abs(c.longitude) > 180) fail('Confirm the bin location.');
  if (body.publicAccess !== true || body.photo?.source !== 'camera') fail('Confirm public access and photograph the bin.');
  const captured = Date.parse(body.photo?.capturedAt);
  if (!Number.isFinite(captured) || captured > now + 30000) fail('Invalid photo date.');
  if (!Array.isArray(body.materials) || !body.materials.length || body.materials.length > 7 || body.materials.some(m => !MATERIALS.includes(m))) fail('Choose the materials listed on the bin.');
  const materials = [...new Set(body.materials)].sort();
  const photo = cleanJPEG(body.photo.data), latitude = +c.latitude.toFixed(5), longitude = +c.longitude.toFixed(5);
  const canonical = {name,notes,latitude,longitude,materials,capturedAt:new Date(captured).toISOString(),photo:digest(photo)};
  return {...canonical,id:body.id.toLowerCase(),photo,requestHash:digest(JSON.stringify(canonical))};
}
export function createBinRoutes(db,now) {
  db.exec(`CREATE TABLE IF NOT EXISTS community_bins(id TEXT PRIMARY KEY, client TEXT NOT NULL, request_hash TEXT NOT NULL,
    name TEXT NOT NULL, notes TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, materials TEXT NOT NULL,
    photo BLOB, photo_digest TEXT NOT NULL, captured TEXT NOT NULL, created INTEGER NOT NULL, removed INTEGER NOT NULL DEFAULT 0);
    CREATE INDEX IF NOT EXISTS community_bins_area ON community_bins(latitude,longitude);
    CREATE INDEX IF NOT EXISTS community_bins_daily ON community_bins(client,created);`);
  const publicBin = (row,client) => ({id:row.id,name:row.name,notes:row.notes,coordinate:{latitude:row.latitude,longitude:row.longitude},
    materials:JSON.parse(row.materials),kind:'Community bin landmark',sourceName:'Community · unverified',publicAccessListed:true,hasFee:false,
    community:true,isMine:row.client === client,createdAt:new Date(row.created).toISOString(),capturedAt:row.captured,hasPhoto:true});
  return async (req,res,send) => {
    const url = new URL(req.url,'http://localhost');
    const client = req.headers['x-installation-id']?.toLowerCase();
    if (!UUID.test(client || '')) return send(res,400,{error:'Missing installation ID.'});
    try {
      if (req.method === 'GET' && url.pathname === '/v1/bins') {
        const latitude = Number(url.searchParams.get('latitude')), longitude = Number(url.searchParams.get('longitude')), radius = Number(url.searchParams.get('radius'));
        if (!url.searchParams.has('latitude') || !url.searchParams.has('longitude') || !Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180 || ![5000,10000,25000].includes(radius)) fail('Choose a location and a 5, 10 or 25 km search radius.');
        const latSpan = radius / 111000;
        // Latitude bounds are safe across the date line and at the poles.
        const rows = db.prepare('SELECT id,client,name,notes,latitude,longitude,materials,created,captured FROM community_bins WHERE removed=0 AND latitude BETWEEN ? AND ?').all(latitude - latSpan,latitude + latSpan);
        const nearby = rows.filter(r => metres({latitude,longitude},r) <= radius).sort((a,b) => metres({latitude,longitude},a) - metres({latitude,longitude},b));
        return send(res,200,{bins:nearby.slice(0,200).map(r => publicBin(r,client)),truncated:nearby.length > 200});
      }
      const match = /^\/v1\/bins\/([0-9a-f-]{36})(\/photo)?$/i.exec(url.pathname);
      if (match && (req.method === 'DELETE' || (req.method === 'GET' && match[2]))) {
        const row = db.prepare('SELECT * FROM community_bins WHERE id=? AND removed=0').get(match[1].toLowerCase());
        if (!row) return send(res,404,{error:'This bin landmark is no longer available.'});
        if (req.method === 'GET') return send(res,200,{mimeType:'image/jpeg',data:Buffer.from(row.photo).toString('base64')});
        if (match[2]) return send(res,404,{error:'Not found.'});
        if (row.client !== client) return send(res,403,{error:'You can remove only landmarks submitted from this installation.'});
        db.prepare('UPDATE community_bins SET removed=1,photo=NULL WHERE id=?').run(row.id);
        return send(res,200,{removed:true});
      }
      if (req.method !== 'POST' || url.pathname !== '/v1/bins') return send(res,404,{error:'Not found.'});
      if (!(req.headers['content-type'] || '').startsWith('application/json')) return send(res,415,{error:'Use JSON.'});
      if (Number(req.headers['content-length'] || 0) > 510000) return send(res,413,{error:'Photo upload is too large.'});
      let size = 0; const chunks = [];
      for await (const chunk of req) { size += chunk.length; if (size > 510000) throw new ClientError('Photo upload is too large.',413); chunks.push(chunk); }
      let body; try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { fail('Invalid JSON.'); }
      const bin = submission(body,now());
      const existing = db.prepare('SELECT * FROM community_bins WHERE id=?').get(bin.id);
      if (existing) {
        if (existing.client !== client || existing.request_hash !== bin.requestHash) throw new ClientError('This bin ID was already used. Save a new landmark.',409);
        if (existing.removed) throw new ClientError('This landmark was removed. Save a new landmark to add it again.',410);
        return send(res,200,{bin:publicBin(existing,client)});
      }
      const duplicate = db.prepare('SELECT * FROM community_bins WHERE removed=0 AND photo_digest=?').all(digest(bin.photo)).find(r => metres({latitude:bin.latitude,longitude:bin.longitude},r) < 20);
      if (duplicate) return send(res,200,{bin:publicBin(duplicate,client),duplicate:true});
      const cutoff = now() - 86400000;
      if (db.prepare('SELECT COUNT(*) AS n FROM community_bins WHERE client=? AND created>?').get(client,cutoff).n >= 20 || db.prepare('SELECT COUNT(*) AS n FROM community_bins WHERE created>?').get(cutoff).n >= 100) throw new ClientError('The daily bin submission limit was reached. Your phone draft can be shared later.',429);
      db.prepare('INSERT INTO community_bins(id,client,request_hash,name,notes,latitude,longitude,materials,photo,photo_digest,captured,created) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)')
        .run(bin.id,client,bin.requestHash,bin.name,bin.notes,bin.latitude,bin.longitude,JSON.stringify(bin.materials),bin.photo,digest(bin.photo),bin.capturedAt,now());
      return send(res,201,{bin:publicBin(db.prepare('SELECT * FROM community_bins WHERE id=?').get(bin.id),client)});
    } catch (error) { return send(res,error instanceof ClientError ? error.status : 500,{error:error instanceof ClientError ? error.message : 'Could not save this landmark. Retry the same draft.'}); }
  };
}
