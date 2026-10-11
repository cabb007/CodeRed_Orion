import test from 'node:test';
import assert from 'node:assert/strict';
import { areaFor, createLocationService, decodeHouston, decodeOverpass, directionsURL, distance, HOUSTON } from '../src/locations.js';
const center = {latitude:40.123456,longitude:-73.987654};
const node = (id,tags = {},extra = {}) => ({type:'node',id,lat:center.latitude,lon:center.longitude,tags:{amenity:'recycling',name:'Community bin',...tags},...extra});
const response = (body,status = 200,retry = null) => ({ok:status === 200,status,headers:{get:() => retry},text:async () => JSON.stringify(body)});
test('search sends rounded coordinates and accepts only bounded supported radii',() => {
  assert.deepEqual(areaFor(center,5000),{latitude:40.123,longitude:-73.988,radius:5000});
  assert.throws(() => areaFor({latitude:91,longitude:0},5000)); assert.throws(() => areaFor(center,100000));
  assert.ok(distance(center,center) < .001);
});
test('parser omits restricted/disused sites, duplicates and invalid coordinates; unknown stays unknown',() => {
  const data = {elements:[node(1),node(1),node(2,{access:'private'}),node(3,{disused:'yes'}),node(4,{}, {lat:100}),
    node(5,{'recycling:plastic_bottles':'yes','recycling:glass':'no',access:'yes'})]};
  const result = decodeOverpass(data);
  assert.equal(result.length,2); assert.equal(result[0].publicAccessListed,false); assert.deepEqual(result[0].materials,[]);
  assert.deepEqual(result[1].materials,['Plastic Bottles']);
  assert.throws(() => decodeOverpass({...data,remark:'runtime timeout'}));
});
test('Houston results require city ownership and reject partial datasets',() => {
  const f = (id,owner) => ({attributes:{OBJECTID:id,Name:'Recycling center',Owner:owner},geometry:{x:-95.37,y:29.76}});
  const data = {features:[f(1,'City of Houston SWMD'),f(2,'Private'),f(1,'City of Houston SWMD')]};
  assert.equal(decodeHouston(data).length,1); assert.throws(() => decodeHouston({...data,exceededTransferLimit:true}));
});
test('service caches fresh searches and falls back to labeled stale data for at most one day',async () => {
  let now = 10000, calls = 0, fail = false;
  const service = createLocationService({clock:() => now,fetchImpl:async (url,options) => {
    calls++; assert.match(decodeURIComponent(options.body),/40.123,-73.988/);
    if (fail) throw new Error('offline'); return response({elements:[node(1)]});
  }});
  const first = await service.search(center,5000); assert.equal(first.locations.length,1);
  await service.search(center,5000); assert.equal(calls,1);
  now += 900001; fail = true;
  const stale = await service.search(center,5000); assert.equal(stale.stale,true); assert.equal(stale.fetchedAt,10000);
  now += 86400000; await assert.rejects(service.search(center,5000),/offline/);
});
test('rate limiting observes Retry-After instead of immediately repeating public requests',async () => {
  let calls = 0, now = 10000;
  const service = createLocationService({clock:() => now,fetchImpl:async () => {calls++; return response({},429,'120');}});
  await assert.rejects(service.search(center,5000)); await assert.rejects(service.search(center,10000)); assert.equal(calls,1);
  now += 120001; await assert.rejects(service.search(center,5000)); assert.equal(calls,2);
});
test('cancellation never publishes or returns stale results',async () => {
  const controller = new AbortController();
  const service = createLocationService({fetchImpl:async () => {controller.abort(); return response({elements:[node(1)]});}});
  await assert.rejects(service.search(center,5000,controller.signal),{name:'AbortError'});
});
test('Houston supplement works during community outage and does not receive user coordinates',async () => {
  const service = createLocationService({fetchImpl:async url => {
    if (url !== HOUSTON) throw new Error('offline');
    return response({features:[{attributes:{OBJECTID:1,Name:'City drop-off',Owner:'City of Houston SWMD'},geometry:{x:-95.37,y:29.76}}]});
  }});
  const result = await service.search({latitude:29.76,longitude:-95.37},5000);
  assert.equal(result.locations.length,1); assert.match(result.notice,/city drop-off/);
});
test('geocoding is explicit, cached, and validates responses',async () => {
  let calls = 0;
  const service = createLocationService({clock:() => 10000,fetchImpl:async url => {
    calls++; assert.match(url,/q=Houston%2C%20TX/); return response([{lat:'29.76',lon:'-95.37',display_name:'Houston'}]);
  }});
  const p = await service.geocode('Houston, TX'); assert.equal(p.latitude,29.76);
  await service.geocode('Houston, TX'); assert.equal(calls,1);
  await assert.rejects(service.geocode(''));
});
test('directions select Apple Maps on iOS and Google Maps on Android',() => {
  const l = {coordinate:center}; assert.match(directionsURL(l,'ios'),/maps.apple.com/);
  assert.match(directionsURL(l,'android'),/google.com\/maps\/dir/);
});

test('place search respects provider backoff across distinct queries', async () => {
  let calls = 0, now = 10000;
  const service = createLocationService({clock:() => now,fetchImpl:async () => { calls++; return response({},429,'120'); }});
  await assert.rejects(service.geocode('Houston, TX'));
  await assert.rejects(service.geocode('Austin, TX'),/busy/); assert.equal(calls,1);
  now += 120001; await assert.rejects(service.geocode('Austin, TX')); assert.equal(calls,2);
});
