import test from 'node:test';
import assert from 'node:assert/strict';
import { boundsFor, drop, settle, stepBody, walk } from '../src/motion.js';
const b = boundsFor({x:10,y:100,width:350,height:400},60,450);
test('fast throws stay bounded and eventually settle in land and ocean habitats',() => {
  for (const gravity of [1450,220]) {
    let p = drop({x:-1000,y:-1000},{x:100000,y:-100000},b);
    assert.equal(p.vx,320); assert.equal(p.vy,-420);
    for (let i = 0; i < 3000 && !p.grounded; i++) {
      p = stepBody(p,1/30,b,gravity);
      assert.ok(p.x >= b.left && p.x <= b.right); assert.ok(p.y >= b.top && p.y <= b.bottom);
    }
    assert.equal(p.grounded,true); assert.equal(p.y,b.bottom); assert.equal(p.vy,0);
  }
});
test('background pauses cannot create a giant physics jump',() => {
  const p = drop({x:150,y:150},{x:100,y:0},b);
  assert.deepEqual(stepBody(p,100,b),stepBody(p,.1,b));
  assert.equal(stepBody(p,NaN,b),p);
});
test('walking stays in bounds and lands exactly at its destination',() => {
  let p = settle({x:100,y:0},b);
  for (let i = 0; i < 1000; i++) p = walk(p,10000,27,1/30,b);
  assert.equal(p.x,b.right); assert.equal(p.grounded,true);
});
test('small viewports and large sprites never invert bounds',() => {
  const small = boundsFor({x:0,y:0,width:50,height:40},200,10);
  assert.ok(small.left <= small.right); assert.ok(small.top <= small.bottom);
  assert.deepEqual(settle({x:300,y:-200},small),{x:25,y:20,vx:0,vy:0,grounded:true});
});
