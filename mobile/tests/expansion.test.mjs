import test from 'node:test';
import assert from 'node:assert/strict';
import { newGame, decodeGame, advance, selectHabitat, habitatID, habitatActions, reward, unlockedAnimals, purchase, buyFood,
  feedPet, moveDecoration, lockDecoration, resetLayout, previewActionCount, POLLUTION_INTERVAL } from '../src/game.js';
import { createGameRepository } from '../src/storage.js';
const earn = (g,id = 'scan',now = 0) => reward(g,{id,submissionId:id,item:'Demo',leaves:20,source:'demo',now});
test('original version-one saves migrate without losing wallets, journal, or decorations',() => {
  const old = {version:1,points:73,litter:2,lastPollution:1000,ownedDecorations:['flowers'],actions:[
    {id:'legacy',submissionId:'before-port',date:new Date(0).toISOString(),item:'Bottle',reward:20,source:'demo'}]};
  const next = decodeGame(JSON.stringify(old));
  assert.equal(next.points,73); assert.deepEqual(next.actions,old.actions); assert.equal(habitatID(next),'grove');
  assert.equal(habitatActions(next).length,1); assert.deepEqual(next.foodInventory,{});
  assert.equal(earn(next,'before-port'),next);
});
test('habitats have independent unlocks and pollution clocks with a shared wallet',() => {
  let g = earn(newGame(0));
  g = selectHabitat(g,'ocean',1000);
  assert.equal(g.points,20); assert.equal(g.litter,3); assert.equal(unlockedAnimals(g)[0].id,'bubbles'); assert.equal(unlockedAnimals(g).length,1);
  g = earn(g,'ocean-scan',1000);
  assert.equal(g.points,40); assert.equal(unlockedAnimals(g)[1].id,'shelly');
  g = selectHabitat(g,'grove',POLLUTION_INTERVAL + 1000);
  assert.equal(g.litter,3); assert.equal(g.lastPollution,POLLUTION_INTERVAL); assert.equal(unlockedAnimals(g)[1].id,'fern');
  assert.equal(habitatActions(g).length,1);
  g = selectHabitat(g,'snow',POLLUTION_INTERVAL + 1000);
  assert.equal(g.litter,3); assert.equal(g.lastPollution,POLLUTION_INTERVAL + 1000); assert.equal(g.points,40);
});
test('receipt and submission deduplication spans every habitat after relaunch',() => {
  let g = reward(newGame(0),{id:'first',submissionId:'a',receiptId:'r',leaves:20,item:'can',source:'ai',now:0});
  g = decodeGame(JSON.stringify(selectHabitat(g,'snow',0)));
  assert.equal(reward(g,{id:'second',submissionId:'b',receiptId:'r',leaves:20,item:'can'}),g);
  assert.equal(earn(g,'a'),g);
});
test('food enforces affordability, inventory caps, habitat, unlocks, and sheltering',() => {
  let g = {...newGame(0),points:10};
  assert.equal(buyFood(g,'kelp'),g);
  g = buyFood(g,'berries'); assert.equal(g.points,5); assert.equal(g.foodInventory.berries,1);
  assert.equal(feedPet(g,'shelly','berries'),g); assert.equal(feedPet(g,'fern','berries'),g);
  g = feedPet(g,'pip','berries'); assert.equal(g.petMeals.pip,1); assert.equal(g.foodInventory.berries,0);
  assert.equal(g.points,5); assert.equal(g.actions.length,0); assert.equal(g.litter,3);
  assert.equal(feedPet(g,'pip','berries'),g);
  g = {...earn(g),litter:6,foodInventory:{berries:1}};
  assert.equal(feedPet(g,'fern','berries'),g);
  assert.equal(feedPet(g,'fern','berries',true).foodInventory.berries,0);
  const full = {...g,foodInventory:{berries:99}}; assert.equal(buyFood(full,'berries'),full);
  const poor = {...g,points:0}; assert.equal(buyFood(poor,'berries'),poor);
});
test('concurrent feeds consume the last snack once and commit before publishing',async () => {
  const original = {...newGame(0),foodInventory:{berries:1}};
  const published = [];
  const repo = createGameRepository({initial:original,decode:decodeGame,write:async () => {},publish:g => published.push(g)});
  const result = await Promise.all([repo.update(g => feedPet(g,'pip','berries')),repo.update(g => feedPet(g,'pip','berries'))]);
  assert.deepEqual(result.map(r => r.applied),[true,false]); assert.equal(repo.get().petMeals.pip,1); assert.equal(published.length,1);
});
test('failed food purchases and decoration moves do not change published progress',async () => {
  const original = {...newGame(0),points:100,ownedDecorations:['flowers']};
  const repo = createGameRepository({initial:original,decode:decodeGame,write:async () => {throw new Error('Disk full');},publish:() => assert.fail('must not publish')});
  await assert.rejects(repo.update(g => buyFood(g,'berries')));
  await assert.rejects(repo.update(g => moveDecoration(g,'flowers',.8,.2)));
  assert.equal(repo.get(),original);
});
test('decoration moves clamp coordinates, respect locks and persist per habitat',() => {
  let g = {...newGame(0),points:500};
  assert.equal(purchase(g,'coral'),g);
  g = moveDecoration(purchase(g,'flowers'),'flowers',2,-1);
  assert.deepEqual(g.decorationPlacements.flowers,{locked:false,x:1,y:0});
  g = lockDecoration(g,'flowers',true); assert.equal(moveDecoration(g,'flowers',.2,.3),g);
  g = selectHabitat(g,'ocean',0); g = moveDecoration(purchase(g,'coral'),'coral',.7,.8);
  assert.equal(moveDecoration(g,'flowers',.2,.3),g);
  g = decodeGame(JSON.stringify(g)); assert.equal(g.decorationPlacements.flowers.locked,true);
  g = resetLayout(g); assert.equal(g.decorationPlacements.coral,undefined); assert.equal(g.decorationPlacements.flowers.x,1);
});
test('expanded corrupt fields are rejected, rather than silently replacing progress',() => {
  for (const fields of [{habitatID:'mars'},{foodInventory:{berries:-1}},{foodInventory:{berries:100}},
    {petMeals:{pip:NaN}},{decorationPlacements:{flowers:{locked:true,x:3,y:.5}}},{otherHabitats:{ocean:{litter:7,lastPollution:1}}}]) {
    assert.throws(() => decodeGame(JSON.stringify({...newGame(0),...fields})));
  }
});
test('preview action count changes only the chosen habitat and leaves the source snapshot intact',() => {
  const original = earn(newGame(0)); const copy = JSON.parse(JSON.stringify(original));
  const preview = previewActionCount(selectHabitat(copy,'ocean',0),6,1000);
  assert.equal(preview.actions.length,7); assert.equal(habitatActions(preview).length,6);
  assert.equal(original.actions.length,1); assert.equal(original.habitatID,'grove'); assert.deepEqual(original.otherHabitats,{});
});
test('zero-leaf developer actions are allowed without enabling zero-leaf live rewards',() => {
  const original = newGame(0), input = {id:'preview',submissionId:'preview',item:'test',leaves:0,cleanup:2,source:'preview',now:0};
  assert.equal(reward(original,input).litter,1);
  assert.equal(reward(original,{...input,source:'demo'}),original);
});
test('long absence catches up once and does not reset partial pollution intervals',() => {
  const g = advance(newGame(0),POLLUTION_INTERVAL * 100 + 123);
  assert.equal(g.litter,6); assert.equal(g.lastPollution,POLLUTION_INTERVAL * 100);
  assert.equal(advance(g,POLLUTION_INTERVAL * 100 + 124),g);
});

test('backup waits for pending progress and cannot overwrite it with an older snapshot', async () => {
  let release;
  const blocked = new Promise(resolve => { release = resolve; }), writes = [];
  const repo = createGameRepository({initial:newGame(0),decode:decodeGame,publish:() => {},
    write:async (key,raw) => { if (writes.length === 0) await blocked; writes.push({key,game:JSON.parse(raw)}); }});
  const update = repo.update(g => earn(g));
  const backup = repo.backup();
  assert.equal(writes.length,0); release(); await Promise.all([update,backup]);
  assert.equal(writes.length,2); assert.equal(writes[1].game.points,20);
  assert.match(writes[1].key,/backup$/);
});
