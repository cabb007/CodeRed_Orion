import test from 'node:test';
import assert from 'node:assert/strict';
import { ANIMALS, condition } from '../src/game.js';
import { expressionCell, MOODS, DROP_SOUNDS } from '../src/animalExpressions.js';
import { createAnimalWorld } from '../src/animalWorld.js';
import { boundsFor, drop, settle, stepBody, walk } from '../src/motion.js';
function separate(world) {
  const all = world.snapshot();
  for (let i = 0; i < all.length; i++) for (let j = i + 1; j < all.length; j++) assert.ok(Math.abs(all[i].x - all[j].x) >= all[i].half + all[j].half + 2 - .001 || Math.abs(all[i].y - all[j].y) >= all[i].halfY + all[j].halfY + 2 - .001,'Animals overlap: ' + all[i].id + ' and ' + all[j].id);
}
test('all twelve animals have four facial variants and individual drop onomatopoeia',() => {
  assert.equal(ANIMALS.length,12);
  for (const animal of ANIMALS) for (let litter = 0; litter <= 6; litter++) {
    const state = condition(litter), face = expressionCell(animal.id,state);
    assert.equal(face.habitat,animal.habitat); assert.ok(face.row >= 0 && face.row < 4); assert.ok(MOODS[state]); assert.ok(DROP_SOUNDS[animal.id].endsWith('!'));
  }
  assert.equal(expressionCell('berries','Polluted'),null);
  assert.deepEqual([0,1,2,3,4,5,6].map(condition),['Thriving','Littered','Littered','Tarnished','Tarnished','Polluted','Polluted']);
});
test('initial coincident placement, roaming, dragging and thrown landings keep animals apart',() => {
  for (const width of [300,370,700]) for (const gravity of [1450,220]) {
    const area = {x:10,y:120,width,height:280}, size = width / 6.6, b = boundsFor(area,size * 1.2,350), world = createAnimalWorld();
    const ids = ['a','b','c','d']; let bodies = ids.map(id => world.move(id,settle({x:width / 2,y:350},b),b,size)); separate(world);
    for (let frame = 0; frame < 500; frame++) {
      for (let i = 0; i < ids.length; i++) {
        const proposed = frame < 200 ? walk(bodies[i],width / 2,27,1/30,b) : frame === 200 ? drop({x:width / 2,y:b.top},{x:(i % 2 ? 1 : -1) * 320,y:-200},b) : stepBody(bodies[i],1/30,b,gravity);
        bodies[i] = world.move(ids[i],proposed,b,size); separate(world);
      }
    }
    bodies[0] = world.move(ids[0],{...bodies[0],x:bodies[1].x,y:bodies[1].y},b,size); separate(world);
    for (const body of world.snapshot()) { assert.ok(body.x >= b.left && body.x <= b.right); assert.ok(body.y >= b.top && body.y <= b.bottom); }
    world.remove('a'); assert.equal(world.snapshot().length,3);
  }
});
