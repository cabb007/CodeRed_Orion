import test from 'node:test';
import assert from 'node:assert/strict';
import { advance, condition, decodeGame, newGame, POLLUTION_INTERVAL, purchase, reward, unlockedAnimals, validReward } from '../src/game.js';
import { buildSubmission, connection, testConnection, validateReceipt } from '../src/verification.js';
import { BACKUP_KEY, createGameRepository, loadGame, SAVE_KEY } from '../src/storage.js';

const id = 'a1111111-1111-4111-8111-111111111111';
const receiptId = 'b1111111-1111-4111-8111-111111111111';
const rewardInput = { id: 'journal-1', submissionId: id, leaves: 20, item: 'Recycling demo', source: 'demo', now: 0 };
const approved = { submissionId: id, receiptId, reviewedAt: new Date(0).toISOString(), status: 'approved', itemName: 'Plastic bottle',
  material: 'plastic', leaves: 20, cleanup: 1, verification: 'gemini_visual_review', evidenceQuality: 'high',
  localAcceptance: 'recyclable_here', acceptanceEvidence: 'printed_label', tip: 'Follow the bin sign.', explanation: 'Visible disposal.', labelEvidence: 'Plastic bottles', limitation: 'Visual evidence only.' };

test('conditions cover all six litter boundaries', () => {
  assert.deepEqual([0, 1, 2, 3, 4, 5, 6].map(condition), ['Thriving', 'Littered', 'Littered', 'Tarnished', 'Tarnished', 'Polluted', 'Polluted']);
});
test('pollution retains partial intervals, caps at six, and ignores reversed clocks', () => {
  const game = newGame(0);
  const later = advance(game, POLLUTION_INTERVAL * 2.5);
  assert.equal(later.litter, 5); assert.equal(later.lastPollution, POLLUTION_INTERVAL * 2);
  assert.equal(advance(later, POLLUTION_INTERVAL * 3).litter, 6);
  assert.equal(advance(game, -100), game); assert.equal(advance(game, 100, 0), game);
  assert.equal(advance(game, POLLUTION_INTERVAL * 100).litter, 6);
});
test('demo rewards persist, unlock Fern, and are idempotent after decoding', () => {
  const awarded = reward(newGame(0), rewardInput);
  assert.equal(awarded.points, 20); assert.equal(awarded.litter, 2);
  assert.equal(unlockedAnimals(awarded).length, 2);
  const saved = decodeGame(JSON.stringify(awarded));
  assert.equal(reward(saved, { ...rewardInput, id: 'journal-2' }), saved);
});
test('receipt IDs and submission IDs independently prevent duplicate rewards', () => {
  const first = reward(newGame(0), { ...rewardInput, receiptId });
  assert.equal(reward(first, { ...rewardInput, submissionId: 'different', receiptId }), first);
  assert.equal(reward(first, { ...rewardInput, receiptId: 'different' }), first);
});
test('purchases require funds, cannot repeat, and leave unrelated state alone', () => {
  const game = { ...newGame(0), points: 60 };
  const bought = purchase(game, 'flowers');
  assert.equal(bought.points, 20); assert.deepEqual(bought.ownedDecorations, ['flowers']);
  assert.equal(purchase(bought, 'flowers'), bought); assert.equal(purchase(bought, 'house'), bought);
  assert.equal(purchase(game, 'unknown'), game); assert.equal(game.points, 60);
});
test('corrupt or future saves are rejected without inventing replacement progress', () => {
  for (const raw of ['{', JSON.stringify({ ...newGame(0), version: 2 }), JSON.stringify({ ...newGame(0), litter: 7 }), JSON.stringify({ ...newGame(0), points: -1 })]) assert.throws(() => decodeGame(raw));
});
test('only complete, matching, correctly valued receipts can approve', () => {
  assert.equal(validReward(approved), true); assert.deepEqual(validateReceipt(approved, id), approved);
  for (const change of [{ leaves: 30 }, { evidenceQuality: 'low' }, { localAcceptance: 'unknown' }, { acceptanceEvidence: 'none' }, { cleanup: 2 }, { verification: 'fake' }, { itemName: '' }]) {
    assert.equal(validReward({ ...approved, ...change }), false);
    assert.throws(() => validateReceipt({ ...approved, ...change }, id));
  }
  assert.throws(() => validateReceipt({ ...approved, submissionId: receiptId }, id));
  assert.throws(() => validateReceipt({ ...approved, receiptId: 'bad' }, id));
});
test('unclear receipts must award zero', () => {
  assert.equal(validateReceipt({ ...approved, status: 'needs_review', leaves: 0, cleanup: 0 }, id).leaves, 0);
  assert.throws(() => validateReceipt({ ...approved, status: 'rejected' }, id));
});
const frames = (now = 100_000) => ['bin', 'item', 'disposal'].map((role, i) => ({ role, capturedAt: new Date(now + i * 1000).toISOString(), data: '/9j/' + ['A', 'B', 'C'][i].repeat(200) }));
test('capture requires ordered, distinct, fresh camera JPEGs; retry payload stays stable', () => {
  const photos = frames();
  const submission = buildSubmission(id, photos, { now: 103_000 });
  assert.deepEqual(submission, buildSubmission(id, photos, { now: 104_000 }));
  assert.equal(submission.photos[0].source, 'camera');
  assert.throws(() => buildSubmission(id, photos.slice(1)));
  assert.throws(() => buildSubmission(id, [...photos].reverse(), { now: 103_000 }));
  assert.throws(() => buildSubmission(id, photos.map(f => ({ ...f, data: photos[0].data })), { now: 103_000 }));
  assert.throws(() => buildSubmission(id, photos, { now: 800_000 }));
  assert.doesNotThrow(() => buildSubmission(id, photos.map(f => ({ ...f, data: photos[0].data })), { demo: true }));
});
test('connection rejects insecure hosts, paths, embedded credentials and short tokens', () => {
  const token = 'access-token-with-24-or-more-characters';
  assert.equal(connection('https://server.example:8787/', token).url, 'https://server.example:8787');
  for (const address of ['http://server.example', 'https://user:pass@server.example', 'https://server.example/path', 'https://server.example?key=secret', 'invalid']) assert.throws(() => connection(address, token));
  assert.throws(() => connection('https://server.example', 'short'));
});
test('connection check sends no photos and rejects invalid server identity', async () => {
  const config = connection('https://server.example', 'access-token-with-24-or-more-characters');
  const fetchImpl = async (url, options) => {
    assert.equal(url, 'https://server.example/v1/status'); assert.equal(options.method, 'GET'); assert.equal(options.body, undefined);
    assert.equal(options.headers.Authorization, `Bearer ${config.token}`); assert.equal(options.redirect, 'error');
    return { ok: true, status: 200, json: async () => ({ service: 'ecogotchi', status: 'ok', reviewsRemaining: 30 }) };
  };
  assert.equal((await testConnection(config, { fetchImpl })).reviewsRemaining, 30);
  await assert.rejects(testConnection(config, { fetchImpl: async () => ({ ok: true, status: 200, json: async () => ({ service: 'other' }) }) }));
  await assert.rejects(testConnection(config, { fetchImpl: async () => ({ status: 401 }) }), /token/);
  await assert.rejects(testConnection(config, { fetchImpl: async () => ({ status: 200, redirected: true }) }), /redirects/);
});
test('repository serializes concurrent mutations and publishes only saved states', async () => {
  const writes = []; const published = [];
  const repo = createGameRepository({ initial: newGame(0), decode: decodeGame, publish: g => published.push(g.points), write: async (key, raw) => {
    await new Promise(resolve => setTimeout(resolve, 5)); writes.push(JSON.parse(raw).points);
  } });
  await Promise.all([repo.update(g => ({ ...g, points: g.points + 20 })), repo.update(g => ({ ...g, points: g.points + 30 }))]);
  assert.equal(repo.get().points, 50); assert.deepEqual(writes, [20, 50]); assert.deepEqual(published, [20, 50]);
});
test('failed saving awards nothing and does not poison a retry', async () => {
  let fail = true; let count = 0;
  const repo = createGameRepository({ initial: newGame(0), decode: decodeGame, publish: () => count++, write: async () => { if (fail) throw new Error('Disk full'); } });
  await assert.rejects(repo.update(g => reward(g, rewardInput))); assert.equal(repo.get().points, 0); assert.equal(count, 0);
  fail = false; await repo.update(g => reward(g, rewardInput)); assert.equal(repo.get().points, 20); assert.equal(count, 1);
});
test('backup recovers a damaged primary save and fresh installs start normally', async () => {
  const backup = JSON.stringify({ ...newGame(0), points: 42 });
  const loaded = await loadGame({ read: async key => key === SAVE_KEY ? '{' : key === BACKUP_KEY ? backup : null, decode: decodeGame, fresh: newGame });
  assert.equal(loaded.game.points, 42); assert.equal(loaded.recovered, true);
  assert.equal((await loadGame({ read: async () => null, decode: decodeGame, fresh: newGame })).recovered, false);
  await assert.rejects(loadGame({ read: async key => key === SAVE_KEY ? '{' : null, decode: decodeGame, fresh: newGame }));
});
