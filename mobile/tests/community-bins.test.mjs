import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createBinRepository } from '../src/binRepository.js';
import { binRequest, mergeBins, shareBin, validateDraft } from '../src/communityBins.js';
const make = () => ({id:randomUUID(),name:'Park bin',notes:'At the entrance',materials:['Paper'],coordinate:{latitude:29.760421,longitude:-95.3698},publicAccess:true,photo:{source:'camera',capturedAt:new Date().toISOString(),data:'/9j/' + 'A'.repeat(196)}});
const memory = () => {
  const index = new Map(), images = new Map(); let fail = false;
  return {index,images,setFail:v => { fail = v; },storage:{getItem:async k => index.get(k) || null,setItem:async (k,v) => { if (fail) throw new Error('disk full'); index.set(k,v); }},
    photos:{save:async (id,data) => { images.set(id,data); return id; },read:async id => { if (!images.has(id)) throw new Error('missing photo'); return images.get(id); },remove:async id => { images.delete(id); }}};
};
test('concurrent saves serialize, photos stay out of the index and survive repository recreation',async () => {
  const adapters = memory(), repository = createBinRepository(adapters), a = make(), b = make();
  await Promise.all([repository.save(a),repository.save(b),repository.save(a)]);
  assert.equal((await repository.list()).length,2); assert.equal(adapters.images.size,2);
  assert.equal([...adapters.index.values()][0].includes(a.photo.data),false);
  const fresh = createBinRepository(adapters), rows = await fresh.list(); assert.equal((await fresh.read(rows[0])).photo.data,a.photo.data);
});
test('failed index writes remove the new photo and a retry can save the draft',async () => {
  const adapters = memory(), repository = createBinRepository(adapters), a = make(); adapters.setFail(true);
  await assert.rejects(repository.save(a),/disk full/); assert.equal(adapters.images.size,0);
  adapters.setFail(false); await repository.save(a); assert.equal((await repository.list()).length,1);
  await repository.remove(a.id); assert.equal((await repository.list()).length,0); assert.equal(adapters.images.size,0);
});
test('publishing records the server identity and keeps a readable photo for offline use',async () => {
  const repository = createBinRepository(memory()), a = make(); await repository.save(a);
  await repository.published(a.id,{id:a.id,community:true,isMine:true},'https://community.example');
  const [record] = await repository.list(); assert.equal(record.server,'https://community.example'); assert.equal((await repository.read(record)).photo.data,a.photo.data);
});
test('merging prevents duplicate published pins and keeps local drafts during provider outages',() => {
  const a = make(), shared = {...a,community:true,isMine:true,sourceName:'Community · unverified'};
  const local = {...a,photoURI:'file:///bin.jpg',shared,server:'https://a.example'};
  const area = {...a.coordinate,radius:5000};
  const merged = mergeBins(area,[],[shared],[local],'https://a.example'); assert.equal(merged.length,1); assert.equal(merged[0].localId,a.id);
  assert.equal(mergeBins(area,[],[],[local],'https://a.example').length,1);
  assert.equal(mergeBins(area,[],[],[local],'https://b.example')[0].onPhone,true);
  assert.equal(mergeBins({...area,latitude:0},[],[],[local],'https://a.example').length,0);
});
test('sharing validates consent, preserves ID on retries and cannot publish from Dev Mode',async () => {
  const a = make(); assert.throws(() => validateDraft({...a,publicAccess:false}));
  const store = {isDeveloperMode:true}; await assert.rejects(shareBin(store,a),/Dev Mode/);
  const bodies = [], fetchImpl = async (url,options) => { bodies.push(JSON.parse(options.body)); assert.equal(options.headers['X-Installation-ID'],'install'); return {ok:true,url,redirected:false,json:async () => ({ok:true})}; };
  for (let i = 0; i < 2; i++) await binRequest('https://a.example','synthetic-token-at-least-24-characters','install','/v1/bins',{method:'POST',body:a,fetchImpl});
  assert.equal(bodies[0].id,bodies[1].id);
  await assert.rejects(binRequest('http://a.example','synthetic-token-at-least-24-characters','install','/v1/bins',{fetchImpl}),/HTTPS/);
});
