export const RADII = [5000,10000,25000];
export const OVERPASS = 'https://overpass-api.de/api/interpreter';
export const GEOCODER = 'https://nominatim.openstreetmap.org/search';
export const HOUSTON = 'https://services2.arcgis.com/LYMgRMwHfrWWEg3s/ArcGIS/rest/services/City_of_Houston_SWMD_Recycling_Disposal_Facilities/FeatureServer/0/query?where=1%3D1&outFields=OBJECTID,Name,Owner&outSR=4326&f=json';
export const validCoordinate = p => Number.isFinite(p?.latitude) && Number.isFinite(p?.longitude) && Math.abs(p.latitude) <= 90 && Math.abs(p.longitude) <= 180;
const checkAbort = signal => { if (signal?.aborted) { const e = new Error('Search cancelled.'); e.name = 'AbortError'; throw e; } };
export function areaFor(center,radius) {
  if (!validCoordinate(center) || !RADII.includes(radius)) throw new Error('Choose a valid location and search radius.');
  return {latitude:Math.round(center.latitude * 1000) / 1000,longitude:Math.round(center.longitude * 1000) / 1000,radius};
}
export function distance(a,b) {
  const r = Math.PI / 180, q = Math.sin((b.latitude - a.latitude) * r / 2) ** 2 +
    Math.cos(a.latitude * r) * Math.cos(b.latitude * r) * Math.sin((b.longitude - a.longitude) * r / 2) ** 2;
  return 6371000 * 2 * Math.asin(Math.sqrt(Math.min(1,Math.max(0,q))));
}
const title = s => s.replaceAll('_',' ').replace(/\b\w/g,c => c.toUpperCase());
const text = v => typeof v === 'string' && v.trim() ? v.trim().slice(0,500) : null;
export function decodeOverpass(data) {
  if (!data || !Array.isArray(data.elements)) throw new Error('The recycling map sent an unreadable response.');
  if (text(data.remark)) throw new Error('The recycling map is busy. Try again in a minute.');
  const seen = new Set();
  return data.elements.flatMap(e => {
    const t = e.tags;
    if (!t || t.amenity !== 'recycling' || !['node','way','relation'].includes(e.type) || !Number.isSafeInteger(e.id) || e.id <= 0) return [];
    const access = typeof t.access === 'string' ? t.access.toLowerCase() : null;
    if (access && !['yes','public','permissive','designated'].includes(access)) return [];
    if ([t.disused,t.abandoned].some(v => ['yes','true','1'].includes(String(v).toLowerCase()))) return [];
    const coordinate = {latitude:e.lat ?? e.center?.lat,longitude:e.lon ?? e.center?.lon}, id = e.type + '/' + e.id;
    if (!validCoordinate(coordinate) || seen.has(id)) return [];
    seen.add(id);
    const kind = {container:'Recycling bin',bin:'Recycling bin',centre:'Drop-off center',reverse_vending_machine:'Bottle & can return'}[t.recycling_type] || 'Recycling point';
    const materials = [...new Set(Object.entries(t).filter(([k,v]) => /^recycling:[^:]+$/.test(k) && v === 'yes').map(([k]) => title(k.slice(10))))].sort();
    return [{id,coordinate,kind,name:text(t.name) || text(t.operator) || kind,materials,
      address:text(t['addr:full']) || text([t['addr:housenumber'],t['addr:street'],t['addr:city'],t['addr:postcode']].filter(Boolean).join(' ')),
      hours:text(t.opening_hours),publicAccessListed:!!access,hasFee:t.fee === 'yes',sourceName:'OpenStreetMap',sourceURL:'https://www.openstreetmap.org/' + id}];
  });
}
export function decodeHouston(data) {
  if (!data || !Array.isArray(data.features) || data.error || data.exceededTransferLimit) throw new Error('City recycling data is unavailable.');
  const seen = new Set();
  return data.features.flatMap(f => {
    const a = f.attributes, coordinate = {latitude:f.geometry?.y,longitude:f.geometry?.x};
    if (!a || a.Owner !== 'City of Houston SWMD' || !text(a.Name) || !Number.isSafeInteger(a.OBJECTID) || seen.has(a.OBJECTID) || !validCoordinate(coordinate)) return [];
    seen.add(a.OBJECTID);
    return [{id:'houston/' + a.OBJECTID,coordinate,name:a.Name,kind:/reuse/i.test(a.Name) ? 'Reuse drop-off' : 'Drop-off center',
      materials:[],publicAccessListed:false,hasFee:false,sourceName:'City of Houston',sourceURL:'https://www.houstontx.gov/solidwaste/recycling_map.html'}];
  });
}
export function directionsURL(location,platform) {
  const {latitude,longitude} = location.coordinate;
  if (!validCoordinate(location.coordinate)) throw new Error('This location has no valid coordinates.');
  return platform === 'ios' ? 'https://maps.apple.com/?daddr=' + latitude + ',' + longitude :
    'https://www.google.com/maps/dir/?api=1&destination=' + latitude + ',' + longitude;
}
export function createLocationService({fetchImpl = fetch,clock = Date.now,overpass = OVERPASS,geocoder = GEOCODER} = {}) {
  const cache = new Map(), geocache = new Map();
  let retryAfter = 0, geocodeRetryAfter = 0, cityCache = null, lastGeocode = 0, geocodeTail = Promise.resolve();
  const request = async (url,options = {},signal,limit = 5000000) => {
    checkAbort(signal);
    const controller = new AbortController(), abort = () => controller.abort();
    signal?.addEventListener('abort',abort);
    const timer = setTimeout(abort,30000);
    try {
      const response = await fetchImpl(url,{...options,headers:{'User-Agent':'EcoGotchi/1.0 (https://github.com/cabb007/CodeRed_Orion)',Accept:'application/json',...options.headers},signal:controller.signal});
      if (response.status === 429 || response.status >= 500) {
        const retry = response.headers?.get?.('Retry-After');
        const seconds = Number.isFinite(Number(retry)) && retry ? Number(retry) : (Date.parse(retry) - clock()) / 1000;
        const e = new Error('The recycling map is busy. Try again in a minute.'); e.retrySeconds = Math.min(300,Math.max(60,seconds || 60)); throw e;
      }
      if (!response.ok) throw new Error('Could not load recycling locations. Check your connection.');
      const raw = await response.text();
      if (raw.length > limit) throw new Error('The recycling map sent an oversized response.');
      checkAbort(signal);
      return JSON.parse(raw);
    } finally { clearTimeout(timer); signal?.removeEventListener('abort',abort); }
  };
  const remember = (map,key,value,max) => { map.delete(key); map.set(key,value); if (map.size > max) map.delete(map.keys().next().value); };
  return {
    async search(center,radius,signal) {
      const area = areaFor(center,radius), key = JSON.stringify(area), now = clock(), saved = cache.get(key);
      checkAbort(signal);
      if (saved && !saved.notice && now - saved.fetchedAt < 900000) return {...saved,stale:false};
      try {
        let locations = [], communityError = null, notice = '';
        try {
          if (now < retryAfter) throw new Error('The recycling map is busy. Try again in a minute.');
          const query = '[out:json][timeout:20][maxsize:16777216];nwr["amenity"="recycling"](around:' + radius + ',' + area.latitude + ',' + area.longitude + ');out center tags;';
          const data = await request(overpass,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded; charset=utf-8'},body:'data=' + encodeURIComponent(query)},signal);
          if (text(data.remark)) retryAfter = clock() + 60000;
          locations = decodeOverpass(data);
        } catch (e) { checkAbort(signal); if (e.retrySeconds) retryAfter = clock() + e.retrySeconds * 1000; communityError = e; }
        if (distance(area,{latitude:29.760,longitude:-95.370}) < 120000) {
          try {
            if (!cityCache || now - cityCache.date >= 86400000) cityCache = {date:now,locations:decodeHouston(await request(HOUSTON,{},signal,1000000))};
            for (const location of cityCache.locations) if (!locations.some(l => l.kind === 'Drop-off center' && distance(l.coordinate,location.coordinate) < 150)) locations.push(location);
            if (communityError) notice = 'Public bin data could not load. Showing city drop-off locations only.';
          } catch { checkAbort(signal); if (communityError) throw communityError; notice = 'City data could not load. Showing community-mapped locations only.'; }
        } else if (communityError) throw communityError;
        checkAbort(signal);
        const result = {area,locations:locations.filter(l => distance(area,l.coordinate) <= radius).sort((a,b) => distance(area,a.coordinate) - distance(area,b.coordinate)),fetchedAt:now,stale:false,notice};
        remember(cache,key,result,8); return result;
      } catch (e) {
        checkAbort(signal);
        if (saved && now - saved.fetchedAt < 86400000) return {...saved,stale:true,notice:'Offline results. Check listings before visiting.'};
        throw e;
      }
    },
    geocode(query,signal) {
      const q = query.trim().slice(0,120);
      if (q.length < 3) return Promise.reject(new Error('Enter a city and state, or a ZIP code.'));
      const key = q.toLowerCase();
      const task = geocodeTail.catch(() => {}).then(async () => {
        checkAbort(signal);
        if (geocache.has(key)) return geocache.get(key);
        // Explicit submitted searches only; no autocomplete. Serialize to respect the public geocoder.
        if (clock() < geocodeRetryAfter) throw new Error('Place search is busy. Try again in a minute.');
        const delay = 1100 - (clock() - lastGeocode);
        if (delay > 0) await new Promise(resolve => setTimeout(resolve,delay));
        checkAbort(signal); lastGeocode = clock();
        let results;
        try { results = await request(geocoder + '?format=jsonv2&limit=1&q=' + encodeURIComponent(q),{},signal,1000000); }
        catch (e) { if (e.retrySeconds) geocodeRetryAfter = clock() + e.retrySeconds * 1000; throw e; }
        const first = results?.[0], p = {latitude:Number(first?.lat),longitude:Number(first?.lon),name:text(first?.display_name) || q};
        if (!first || !validCoordinate(p)) throw new Error('No matching area found. Try a city and state.');
        remember(geocache,key,p,16); return p;
      });
      geocodeTail = task; return task;
    },
  };
}
