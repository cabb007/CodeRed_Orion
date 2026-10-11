import test from 'node:test';
import assert from 'node:assert/strict';
import { createGameModes } from '../src/gameModes.js';
import { createGameRepository, SAVE_KEY } from '../src/storage.js';
import { newGame, decodeGame, purchase, buyFood, reward, selectHabitat, moveDecoration, lockDecoration, previewActionCount } from '../src/game.js';

function fixture({write,preferencesIdle,initial} = {}) {
  const writes = [], snapshots = [];
  let preferences = {mode:'ai',sound:true,url:'https://real.example'};
  const repository = createGameRepository({initial:initial || {...newGame(),points:500},decode:decodeGame,
    write:async (key,value) => { if (write) await write(key,value); writes.push([key,value]); },publish:() => {}});
  const modes = createGameModes({repository,decode:decodeGame,advance:g => g,getPreferences:() => preferences,
    preferencesIdle:preferencesIdle || (() => Promise.resolve()),publish:s => snapshots.push(s)});
  return {repository,modes,writes,snapshots,getPreferences:() => preferences,setPreferences:p => { preferences = p; }};
}
test('developer rewards, spending, food, placements, habitat switches and reset never persist',async () => {
  const f = fixture(), original = structuredClone(f.repository.get());
  await f.modes.setEnabled(true); const id = f.modes.snapshot().sessionId;
  await f.modes.update(id,g => reward(g,{id:'dev',submissionId:'dev',item:'Developer',leaves:100,source:'preview'}));
  await f.modes.update(id,g => purchase(g,'flowers'));
  await f.modes.update(id,g => buyFood(g,'berries'));
  await f.modes.update(id,g => moveDecoration(g,'flowers',.2,.4));
  await f.modes.update(id,g => lockDecoration(g,'flowers',true));
  assert.equal(f.modes.snapshot().game.points,600 - 40 - 5);
  assert.equal(f.modes.snapshot().game.foodInventory.berries,1);
  assert.equal(f.modes.snapshot().game.decorationPlacements.flowers.locked,true);
  await f.modes.update(id,g => selectHabitat(g,'ocean'));
  assert.equal(f.modes.snapshot().game.habitatID,'ocean');
  await f.modes.update(id,g => previewActionCount(g,6));
  assert.equal(f.modes.snapshot().game.actions.filter(a => a.habitatID === 'ocean').length,6);
  await f.modes.update(id,() => newGame());
  await f.modes.setEnabled(false);
  assert.deepEqual(f.modes.snapshot().game,original);
  assert.deepEqual(f.repository.get(),original);
  assert.deepEqual(f.writes,[]);
});
test('developer preferences are temporary, force demo scans, and return to saved preferences',async () => {
  const f = fixture(), real = {...f.getPreferences()};
  await f.modes.setEnabled(true);
  assert.equal(f.modes.snapshot().preferences.mode,'demo');
  f.modes.setTemporaryPreferences(f.modes.snapshot().sessionId,{mode:'ai',sound:false,url:'https://temporary.example'});
  assert.deepEqual(f.getPreferences(),real);
  assert.equal(f.modes.snapshot().preferences.mode,'demo');
  await f.modes.setEnabled(false);
  assert.deepEqual(f.modes.snapshot().preferences,real); assert.deepEqual(f.writes,[]);
});
test('entering Dev Mode waits for pending real saves before copying the habitat',async () => {
  let finish, started;
  const saving = new Promise(r => { started = r; }), gate = new Promise(r => { finish = r; });
  const f = fixture({write:async key => { if (key === SAVE_KEY) { started(); await gate; } }});
  const update = f.modes.update(0,g => ({...g,points:777}));
  await saving;
  const enter = f.modes.setEnabled(true);
  assert.equal(f.modes.snapshot().changing,true);
  await assert.rejects(f.modes.update(f.modes.snapshot().sessionId,g => ({...g,points:123})),/mode changed/);
  finish(); await Promise.all([enter,update]);
  assert.equal(f.modes.snapshot().game.points,777);
  assert.equal(f.repository.get().points,777);
});
test('entering Dev Mode also waits for pending real preference saves',async () => {
  let finish; const gate = new Promise(r => { finish = r; });
  const f = fixture({preferencesIdle:() => gate});
  const enter = f.modes.setEnabled(true);
  f.setPreferences({mode:'ai',sound:false,url:'https://latest.example'});
  finish(); await enter;
  assert.equal(f.modes.snapshot().preferences.sound,false);
  assert.equal(f.modes.snapshot().preferences.url,'https://latest.example');
});
test('late developer callbacks cannot reward, reset, or change settings after returning to real mode',async () => {
  const f = fixture(); await f.modes.setEnabled(true); const old = f.modes.snapshot().sessionId;
  await f.modes.setEnabled(false);
  await assert.rejects(f.modes.update(old,g => ({...g,points:9999})),/mode changed/);
  await assert.rejects(f.modes.update(old,() => newGame()),/mode changed/);
  assert.throws(() => f.modes.setTemporaryPreferences(old,{sound:false}),/mode changed/);
  assert.throws(() => f.modes.assertReal(old),/mode changed/);
  assert.equal(f.repository.get().points,500); assert.deepEqual(f.writes,[]);
  await f.modes.setEnabled(true);
  await assert.rejects(f.modes.update(old,g => ({...g,points:9999})),/mode changed/);
  assert.equal(f.modes.snapshot().game.points,500);
});
test('real actions captured before switching cannot write to the developer session',async () => {
  const f = fixture(); await f.modes.setEnabled(true);
  await assert.rejects(f.modes.update(0,g => ({...g,points:999})),/mode changed/);
  assert.throws(() => f.modes.assertReal(f.modes.snapshot().sessionId),/Turn off Dev Mode/);
  await f.modes.setEnabled(false);
  const saved = await f.modes.update(f.modes.snapshot().sessionId,g => ({...g,points:520}));
  assert.equal(saved.applied,true); assert.equal(f.repository.get().points,520);
  assert.equal(f.writes.filter(([key]) => key === SAVE_KEY).length,1);
});
test('a sandbox tick changes only the sandbox and polling can be paused',async () => {
  const f = fixture();
  // Inject a deterministic advance function to check mode routing and pause behavior.
  const modes = createGameModes({repository:f.repository,decode:decodeGame,
    advance:(g,now,interval) => now ? {...g,litter:Math.min(6,g.litter + 1),lastPollution:now} : g,
    getPreferences:f.getPreferences,preferencesIdle:async () => {},publish:() => {}});
  await modes.setEnabled(true);
  modes.tick({pausePollution:true,interval:5000});
  assert.equal(modes.snapshot().game.litter,3);
  modes.tick({pausePollution:false,interval:5000});
  assert.equal(modes.snapshot().game.litter,4);
  assert.equal(f.repository.get().litter,3); assert.deepEqual(f.writes,[]);
});
test('mode toggling is serialized and every new session rejects old callbacks',async () => {
  let finish; const gate = new Promise(r => { finish = r; });
  const f = fixture({preferencesIdle:() => gate});
  const entering = f.modes.setEnabled(true);
  await assert.rejects(f.modes.setEnabled(false),/Wait/);
  finish(); await entering;
  const id = f.modes.snapshot().sessionId;
  await f.modes.setEnabled(true); assert.equal(f.modes.snapshot().sessionId,id);
  await f.modes.setEnabled(false); await f.modes.setEnabled(true);
  assert.notEqual(f.modes.snapshot().sessionId,id);
});
