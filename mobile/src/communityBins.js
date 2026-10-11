import { connection } from './verification.js';
import { distance, validCoordinate } from './locations.js';
export const BIN_MATERIALS = ['Paper','Cardboard','Plastic','Metal','Glass','Other','Unknown'];
export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function validateDraft(bin) {
  if (!UUID.test(bin?.id) || typeof bin.name !== 'string' || bin.name.trim().length < 2 || bin.name.trim().length > 80 || typeof bin.notes !== 'string' || bin.notes.length > 500 || !validCoordinate(bin.coordinate)) throw new Error('Add a name, valid map position, and notes under 500 characters.');
  if (!Array.isArray(bin.materials) || !bin.materials.length || bin.materials.some(m => !BIN_MATERIALS.includes(m))) throw new Error('Choose the materials on the bin’s label, or Unknown.');
  if (!bin.publicAccess || bin.photo?.source !== 'camera' || !Number.isFinite(Date.parse(bin.photo?.capturedAt)) || typeof bin.photo.data !== 'string' || bin.photo.data.length > 500000 || !bin.photo.data.startsWith('/9j/')) throw new Error('Photograph the bin and confirm public access.');
  return {...bin,name:bin.name.trim(),notes:bin.notes.trim(),coordinate:{latitude:+bin.coordinate.latitude.toFixed(5),longitude:+bin.coordinate.longitude.toFixed(5)}};
}
export function decodeBin(bin) {
  if (!UUID.test(bin?.id) || !validCoordinate(bin.coordinate) || typeof bin.name !== 'string' || bin.name.length > 80 || typeof bin.notes !== 'string' || bin.notes.length > 500 || !Array.isArray(bin.materials) || bin.materials.some(m => !BIN_MATERIALS.includes(m)) || bin.community !== true) throw new Error('The community server returned an invalid bin.');
  return {...bin,id:bin.id.toLowerCase(),isMine:bin.isMine === true,kind:'Community bin landmark',sourceName:'Community · unverified',publicAccessListed:true,hasFee:false};
}
export async function binRequest(address,token,installationId,route,{method='GET',body,signal,fetchImpl=fetch} = {}) {
  const config = connection(address,token), controller = new AbortController();
  const abort = () => controller.abort(); if (signal?.aborted) abort(); signal?.addEventListener('abort',abort);
  const timer = setTimeout(abort,20000);
  try {
    const response = await fetchImpl(config.url + route,{method,redirect:'error',signal:controller.signal,
      headers:{Authorization:'Bearer ' + config.token,'X-Installation-ID':installationId,...(body ? {'Content-Type':'application/json'} : {})},...(body ? {body:JSON.stringify(body)} : {})});
    if (response.redirected || (response.url && new URL(response.url).origin !== config.url)) throw new Error('Use the server’s direct HTTPS address.');
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || 'The community server could not finish this request.');
    return result;
  } catch (e) { if (controller.signal.aborted) throw new Error(signal?.aborted ? 'Cancelled.' : 'Connection timed out. Your draft stays on this phone.'); throw e; }
  finally { clearTimeout(timer); signal?.removeEventListener('abort',abort); }
}
export async function findCommunity(store,area,signal) {
  const result = await binRequest(store.preferences.url,store.token,store.installationId,`/v1/bins?latitude=${area.latitude}&longitude=${area.longitude}&radius=${area.radius}`,{signal});
  if (!Array.isArray(result.bins) || result.bins.length > 200) throw new Error('The community server returned an invalid map.');
  return {bins:result.bins.map(decodeBin),truncated:result.truncated === true};
}
export async function shareBin(store,draft,signal) {
  if (store.isDeveloperMode) throw new Error('Leave Dev Mode before sharing a landmark.');
  store.assertReal?.();
  const result = await binRequest(store.preferences.url,store.token,store.installationId,'/v1/bins',{method:'POST',body:validateDraft(draft),signal});
  return decodeBin(result.bin);
}
export function mergeBins(area,listed,community,local,origin) {
  const map = new Map(listed.map(b => [b.id,b]));
  for (const bin of local) {
    const sharedHere = bin.shared && bin.server === origin;
    const id = sharedHere ? bin.shared.id : bin.id;
    map.set(id,{...bin,...(sharedHere ? bin.shared : {}),id,localId:bin.id,onPhone:!sharedHere,community:!!sharedHere,isMine:sharedHere ? bin.shared.isMine : false,
      kind:sharedHere ? 'Community bin landmark' : 'Bin saved on this phone',sourceName:sharedHere ? 'Community · phone cache · unverified' : 'On this phone',hasPhoto:true,photoURI:bin.photoURI});
  }
  for (const bin of community) map.set(bin.id,{...map.get(bin.id),...bin});
  return [...map.values()].filter(b => validCoordinate(b.coordinate) && distance(area,b.coordinate) <= area.radius).sort((a,b) => distance(area,a.coordinate) - distance(area,b.coordinate));
}
