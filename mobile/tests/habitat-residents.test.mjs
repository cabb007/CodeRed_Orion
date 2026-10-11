import test from 'node:test';
import assert from 'node:assert/strict';
import { MAX_HABITAT_ANIMALS, residentSpriteSize, selectHabitatResidents } from '../src/habitatResidents.js';
import { ANIMALS, newGame, previewActionCount, residentAnimals, selectHabitat } from '../src/game.js';
import { createAnimalWorld } from '../src/animalWorld.js';
import { boundsFor, drop, settle, stepBody, walk } from '../src/motion.js';

test('residency caps eligible animals at four after habitat, unlock, visibility and shelter filtering',() => {
  const catalog = [...ANIMALS,...Array.from({length:5},(_,i) => ({id:'future-' + i,habitat:'grove',required:0}))];
  const options = {habitat:'grove',actionCount:6,litter:0};
  assert.equal(MAX_HABITAT_ANIMALS,4);
  assert.deepEqual(selectHabitatResidents(catalog,options).map(a => a.id),['pip','fern','clover','maple']);
  assert.deepEqual(selectHabitatResidents(catalog,{...options,hiddenAnimals:['pip','fern']}).map(a => a.id),['clover','maple','future-0','future-1']);
  assert.equal(selectHabitatResidents(catalog,{...options,litter:6,ignoreRetreat:true}).length,4);
  assert.equal(selectHabitatResidents(ANIMALS,{...options,litter:6}).length,1);
  assert.equal(selectHabitatResidents(ANIMALS,{...options,actionCount:0}).length,1);
  for (const habitat of ['grove','ocean','snow']) {
    const game = {...previewActionCount(selectHabitat(newGame(),habitat),6),litter:0};
    assert.equal(residentAnimals(game).length,4);
    assert.ok(residentAnimals(game).every(a => a.habitat === habitat));
    assert.equal(residentAnimals(game,{hiddenAnimals:[residentAnimals(game)[0].id]}).length,3);
  }
});

test('the collision world refuses a fifth animal but allows replacing a removed resident',() => {
  const world = createAnimalWorld(), b = boundsFor({x:0,y:0,width:400,height:300},48,200);
  for (let i = 0; i < 4; i++) world.move(String(i),settle({x:50 + i * 100,y:200},b),b,40);
  assert.throws(() => world.move('fifth',settle({x:200,y:200},b),b,40),/at most four/);
  assert.equal(world.snapshot().length,4);
  world.move('0',settle({x:100,y:200},b),b,40); assert.equal(world.snapshot().length,4);
  world.remove('0'); world.move('fifth',settle({x:50,y:200},b),b,40); assert.equal(world.snapshot().length,4);
});

test('collisions between different ground levels preserve the walking animal’s height',() => {
  const world = createAnimalWorld(), area = {x:10,y:100,width:370,height:450}, size = 56;
  const lower = boundsFor(area,size * 1.2,450), upper = boundsFor(area,size * 1.2,410);
  world.move('lower',settle({x:170,y:450},lower),lower,size);
  const body = world.move('upper',settle({x:170,y:410},upper),upper,size);
  assert.equal(body.y,upper.bottom);
  assert.equal(body.grounded,true);
  assert.notEqual(body.x,170);
});

function assertSeparate(world) {
  const all = world.snapshot();
  for (let i = 0; i < all.length; i++) for (let j = i + 1; j < all.length; j++) {
    assert.ok(Math.abs(all[i].x - all[j].x) >= all[i].half + all[j].half + 2 - .001 ||
      Math.abs(all[i].y - all[j].y) >= all[i].halfY + all[j].halfY + 2 - .001,'Residents overlapped.');
  }
}

test('all four residents stay grounded and roam at phone sizes that previously froze one animal',() => {
  for (const [width,height] of [[320,568],[390,844],[430,932]]) for (const habitat of ['grove','ocean','snow']) {
    const ww = Math.max(width,height * 9 / 16), wh = Math.max(height,width * 16 / 9), ox = (ww - width) / 2, oy = (wh - height) / 2;
    const top = Math.max(height * .33,Math.min(285,height * .48));
    const area = {x:10,y:top,width:width - 20,height:Math.max(1,height - Math.min(205,height * .4) - top)};
    const size = residentSpriteSize(area,ww * .15,4), world = createAnimalWorld();
    const homes = [.34,.65,.60,.27].map((x,i) => ({x:ww * x - ox,y:wh * (habitat === 'ocean' ? [.52,.60,.67,.56] : [.68,.65,.73,.70])[i] - oy}));
    const bounds = homes.map(h => boundsFor(area,size * 1.2,h.y));
    const bodies = [], target = Array(4).fill(null), nextWalk = Array(4).fill(0), travel = [];
    for (let i = 0; i < 4; i++) {
      world.listen(String(i),body => { bodies[i] = body; target[i] = null; });
      bodies[i] = world.move(String(i),settle(homes[i],bounds[i]),bounds[i],size);
    }
    for (let i = 0; i < 4; i++) {
      bodies[i] = world.move(String(i),settle(bodies[i],bounds[i]),bounds[i],size);
      travel[i] = [bodies[i].x,bodies[i].x];
      assert.equal(bodies[i].grounded,true,`${width} ${habitat}: resident ${i} spawned airborne.`);
    }
    let seed = 456;
    const random = () => { seed = (Math.imul(seed,1664525) + 1013904223) >>> 0; return seed / 2 ** 32; };
    // Exercise the same walking, collision and retry timing as InteractivePet.
    for (let frame = 0; frame < 1800; frame++) for (let i = 0; i < 4; i++) {
      let n = bodies[i]; const now = frame * 1000 / 30, b = bounds[i];
      if (!n.grounded) n = stepBody(n,1 / 30,b,habitat === 'ocean' ? 220 : 1450);
      else {
        if (target[i] === null && now >= nextWalk[i]) target[i] = b.left + random() * (b.right - b.left);
        if (target[i] !== null) {
          n = walk(n,target[i],i === 3 ? 27 : 21,1 / 30,b);
          if (Math.abs(target[i] - n.x) < .5) { target[i] = null; nextWalk[i] = now + 1200 + random() * 1800; }
        }
      }
      const moved = world.move(String(i),n,b,size);
      if (Math.abs(moved.x - n.x) > .1 || Math.abs(moved.y - n.y) > .1) { target[i] = null; nextWalk[i] = now + 700; }
      bodies[i] = moved; travel[i][0] = Math.min(travel[i][0],moved.x); travel[i][1] = Math.max(travel[i][1],moved.x);
      assert.equal(moved.grounded,true,`${width} ${habitat}: collision left resident ${i} airborne.`);
      assertSeparate(world);
    }
    for (const [i,[min,max]] of travel.entries()) assert.ok(max - min > 12,`${width} ${habitat}: resident ${i} did not roam.`);
    // A drop onto another resident must eventually land instead of hovering.
    bodies[2] = world.move('2',drop({x:bodies[1].x,y:bounds[2].top},{x:0,y:0},bounds[2]),bounds[2],size);
    for (let frame = 0; frame < 3000 && !bodies[2].grounded; frame++) {
      bodies[2] = world.move('2',stepBody(bodies[2],1 / 30,bounds[2],habitat === 'ocean' ? 220 : 1450),bounds[2],size);
      assertSeparate(world);
    }
    assert.equal(bodies[2].grounded,true,`${width} ${habitat}: dropped resident never landed.`);
  }
});
