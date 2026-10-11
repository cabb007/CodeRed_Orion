import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createVerificationServer } from './server.mjs';
import { cleanJPEG } from './community-bins.mjs';
const token = 'synthetic-community-test-token-12345';
const photo = readFileSync(new URL('./fixtures/bin.jpg',import.meta.url));
const now = Date.parse('2026-10-11T12:00:00Z');
const draft = (overrides={}) => ({id:randomUUID(),name:'Library bin',notes:'By the front door',coordinate:{latitude:29.760421,longitude:-95.369803},materials:['Paper'],publicAccess:true,
  photo:{source:'camera',capturedAt:new Date(now).toISOString(),data:photo.toString('base64')},...overrides});
async function start(t,options={}) {
  const server = createVerificationServer({token,verify:null,now:() => now,...options});
  await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
  t.after(() => server.listening ? new Promise(resolve => server.close(resolve)) : undefined);
  const client = randomUUID();
  return {server,client,request:async (route,{method='GET',body,headers={}}={}) => {
    const response = await fetch(`http://127.0.0.1:${server.address().port}${route}`,{method,headers:{Authorization:'Bearer ' + token,'X-Installation-ID':client,'Content-Type':'application/json',...headers},...(body ? {body:JSON.stringify(body)} : {})});
    return {status:response.status,body:await response.json()};
  }};
}
const nearby = '/v1/bins?latitude=29.760&longitude=-95.370&radius=5000';
test('community sharing works without Gemini and never issues recycling rewards',async t => {
  const api = await start(t), status = (await api.request('/v1/status')).body;
  assert.equal(status.communityBins,true); assert.equal(status.aiReview,false); assert.equal(status.reviewsRemaining,0);
  assert.equal((await api.request('/v1/recycling/verify',{method:'POST',body:{}})).status,503);
  const saved = await api.request('/v1/bins',{method:'POST',body:draft()});
  assert.equal(saved.status,201); assert.equal(saved.body.bin.isMine,true); assert.equal(saved.body.bin.leaves,undefined);
  assert.equal(saved.body.bin.coordinate.latitude,29.76042);
  const listed = await api.request(nearby); assert.equal(listed.body.bins.length,1); assert.equal(listed.body.bins[0].photo,undefined); assert.equal(listed.body.bins[0].client,undefined);
  const image = await api.request('/v1/bins/' + saved.body.bin.id + '/photo');
  assert.equal(image.body.mimeType,'image/jpeg'); assert.deepEqual(Buffer.from(image.body.data,'base64'),cleanJPEG(photo.toString('base64')));
});
test('authentication, public access, camera source, coordinates and malformed photos fail closed',async t => {
  const api = await start(t);
  assert.equal((await api.request(nearby,{headers:{Authorization:'Bearer incorrect'}})).status,401);
  assert.equal((await api.request(nearby,{headers:{'X-Installation-ID':'bad'}})).status,400);
  for (const body of [draft({publicAccess:false}),draft({coordinate:{latitude:91,longitude:0}}),draft({photo:{source:'gallery'}}),draft({materials:['Batteries']}),draft({photo:{source:'camera',capturedAt:new Date(now).toISOString(),data:'/9j/' + 'A'.repeat(200)}})]) assert.equal((await api.request('/v1/bins',{method:'POST',body})).status,400);
  assert.equal((await api.request('/v1/bins',{method:'POST',body:draft({notes:'x'.repeat(510000)})})).status,413);
  assert.equal((await api.request('/v1/bins?latitude=0&longitude=0&radius=99999')).status,400);
  assert.equal((await api.request('/v1/bins?longitude=0&radius=5000')).status,400);
  assert.equal((await api.request(nearby)).body.bins.length,0);
});
test('retries are idempotent, conflicting reuse fails and near duplicates return the existing landmark',async t => {
  const api = await start(t), body = draft();
  const first = await api.request('/v1/bins',{method:'POST',body});
  const again = await api.request('/v1/bins',{method:'POST',body}); assert.equal(again.status,200); assert.deepEqual(again.body,first.body);
  assert.equal((await api.request('/v1/bins',{method:'POST',body:{...body,name:'Different bin'}})).status,409);
  const duplicate = await api.request('/v1/bins',{method:'POST',body:draft()}); assert.equal(duplicate.body.bin.id,body.id); assert.equal(duplicate.body.duplicate,true);
  assert.equal((await api.request(nearby)).body.bins.length,1);
});
test('another installation can view a pin and photo but cannot remove it',async t => {
  const api = await start(t), body = draft(); await api.request('/v1/bins',{method:'POST',body});
  const other = {'X-Installation-ID':randomUUID()};
  assert.equal((await api.request(nearby,{headers:other})).body.bins[0].isMine,false);
  assert.equal((await api.request('/v1/bins/' + body.id,{method:'DELETE',headers:other})).status,403);
  assert.equal((await api.request('/v1/bins/' + body.id,{method:'DELETE'})).status,200);
  assert.equal((await api.request(nearby)).body.bins.length,0);
  assert.equal((await api.request('/v1/bins/' + body.id + '/photo')).status,404);
  assert.equal((await api.request('/v1/bins',{method:'POST',body})).status,410);
});
test('nearby searches handle the date line and exclude distant bins',async t => {
  const api = await start(t);
  await api.request('/v1/bins',{method:'POST',body:draft({coordinate:{latitude:0,longitude:179.999}})});
  await api.request('/v1/bins',{method:'POST',body:draft({coordinate:{latitude:40,longitude:0}})});
  const result = await api.request('/v1/bins?latitude=0&longitude=-179.999&radius=5000'); assert.equal(result.body.bins.length,1);
});
test('landmarks and daily submission limits survive restarts',async t => {
  const directory = mkdtempSync(join(tmpdir(),'ecogotchi-bins-'));
  const databasePath = join(directory,'test.sqlite'), api = await start(t,{databasePath});
  for (let i = 0; i < 20; i++) assert.equal((await api.request('/v1/bins',{method:'POST',body:draft({coordinate:{latitude:29.76 + i * .001,longitude:-95.37}})})).status,201);
  await new Promise(resolve => api.server.close(resolve));
  const reopened = await start(t,{databasePath});
  t.after(() => rmSync(directory,{recursive:true,force:true}));
  assert.equal((await reopened.request(nearby)).body.bins.length,20);
  assert.equal((await reopened.request('/v1/bins',{method:'POST',body:draft({coordinate:{latitude:29.79,longitude:-95.37}}),headers:{'X-Installation-ID':api.client}})).status,429);
});
test('JPEG metadata is removed while compressed image data stays intact',() => {
  const secret = Buffer.from('Exif\0\0private GPS metadata');
  const segment = Buffer.alloc(secret.length + 4); segment[0] = 255; segment[1] = 225; segment.writeUInt16BE(secret.length + 2,2); secret.copy(segment,4);
  const withExif = Buffer.concat([photo.subarray(0,2),segment,photo.subarray(2)]);
  const result = cleanJPEG(withExif.toString('base64'));
  assert.equal(result.includes(secret),false); assert.deepEqual(result,cleanJPEG(photo.toString('base64')));
  assert.throws(() => cleanJPEG(photo.subarray(0,-2).toString('base64')));
});
