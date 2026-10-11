import test from 'node:test';
import assert from 'node:assert/strict';
import { firstPosition } from '../src/firstPosition.js';
test('one-shot position releases a subscription that arrives after its first callback', async () => {
  let removed = 0;
  const position = await firstPosition(success => {
    success({ latitude: 1, longitude: 2 });
    return Promise.resolve({ remove: () => removed++ });
  });
  await Promise.resolve();
  assert.equal(position.latitude, 1); assert.equal(removed, 1);
});
test('cancelling a pending location read rejects and releases its watcher exactly once', async () => {
  const controller = new AbortController(); let removed = 0, success;
  const pending = firstPosition(callback => {
    success = callback; return { remove: () => removed++ };
  }, { signal: controller.signal });
  await Promise.resolve(); controller.abort();
  await assert.rejects(pending, { name: 'AbortError' });
  success({ latitude: 1, longitude: 2 }); assert.equal(removed, 1);
});
test('location timeout releases the watcher, and an already cancelled read never subscribes', async () => {
  let removed = 0;
  await assert.rejects(firstPosition(() => ({ remove: () => removed++ }), { timeoutMs: 5 }), /too long/);
  assert.equal(removed, 1);
  const controller = new AbortController(); controller.abort();
  await assert.rejects(firstPosition(() => assert.fail('must not start'), { signal: controller.signal }), { name: 'AbortError' });
});
test('synchronous and asynchronous location errors reject cleanly', async () => {
  await assert.rejects(firstPosition(() => { throw new Error('native failure'); }), /native failure/);
  await assert.rejects(firstPosition(() => Promise.reject(new Error('permission failure'))), /permission failure/);
});
