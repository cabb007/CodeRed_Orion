import http from 'node:http';
import { timingSafeEqual, randomUUID } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { DatabaseSync } from 'node:sqlite';
import { ClientError, decide, validateSubmission } from './policy.mjs';
import { createGeminiVerifier } from './gemini.mjs';
import { createBinRoutes } from './community-bins.mjs';

export function createVerificationServer({ token, verify, databasePath = ':memory:', dailyReviewLimit = 30, now = () => Date.now() }) {
  if (!token || token.length < 24) throw new Error('ECOGOTCHI_ACCESS_TOKEN must have at least 24 characters.');
  if (!Number.isSafeInteger(dailyReviewLimit) || dailyReviewLimit < 0) throw new Error('DAILY_REVIEW_LIMIT must be a nonnegative integer.');
  if (databasePath !== ':memory:') mkdirSync(dirname(resolve(databasePath)), { recursive: true });
  const db = new DatabaseSync(databasePath);
  db.exec(`PRAGMA journal_mode=WAL;
    CREATE TABLE IF NOT EXISTS submissions(client TEXT, id TEXT, request_hash TEXT, response TEXT, approved INTEGER, created INTEGER, PRIMARY KEY(client,id));
    CREATE TABLE IF NOT EXISTS evidence(digest TEXT PRIMARY KEY, created INTEGER);
    CREATE INDEX IF NOT EXISTS submissions_daily ON submissions(client, created);
    CREATE TABLE IF NOT EXISTS review_attempts(id TEXT PRIMARY KEY, client TEXT, created INTEGER);
    CREATE INDEX IF NOT EXISTS review_attempts_created ON review_attempts(created);`);
  const bins = createBinRoutes(db,now);
  const inFlight = new Set();
  const rate = new Map();
  let active = 0;
  const authenticate = header => {
    const expected = Buffer.from(`Bearer ${token}`); const supplied = Buffer.from(header ?? '');
    return supplied.length === expected.length && timingSafeEqual(expected, supplied);
  };
  const send = (res, status, body) => {
    res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
    res.end(JSON.stringify(body));
  };
  const server = http.createServer(async (req, res) => {
    if (req.method === 'GET' && req.url === '/health') return send(res, 200, { status: 'ok' });
    const connectionCheck = req.method === 'GET' && req.url === '/v1/status';
    const binRequest = /^\/v1\/bins(?:[/?]|$)/.test(req.url);
    if (!binRequest && !connectionCheck && (req.method !== 'POST' || req.url !== '/v1/recycling/verify')) return send(res, 404, { error: 'Not found.' });
    if (!authenticate(req.headers.authorization)) return send(res, 401, { error: 'Check the EcoGotchi server access token.' });
    if (binRequest) return bins(req,res,send);
    if (connectionCheck) {
      const used = db.prepare('SELECT COUNT(*) AS count FROM review_attempts WHERE created>?').get(now() - 86_400_000).count;
      return send(res, 200, { service: 'ecogotchi', status: 'ok', reviewsRemaining: verify ? Math.max(0, dailyReviewLimit - used) : 0, communityBins: true, aiReview: !!verify });
    }
    if (!verify) return send(res,503,{error:'AI review is not configured. Community bins are available.'});
    const client = req.headers['x-installation-id']?.toLowerCase();
    if (typeof client !== 'string' || !/^[a-f0-9-]{36}$/i.test(client)) return send(res, 400, { error: 'Missing installation ID.' });
    if (!(req.headers['content-type'] ?? '').startsWith('application/json')) return send(res, 415, { error: 'Use JSON.' });
    if (Number(req.headers['content-length'] ?? 0) > 6_100_000) return send(res, 413, { error: 'Photo upload is too large.' });
    let lock;
    try {
      let size = 0; const chunks = [];
      for await (const chunk of req) {
        size += chunk.length;
        if (size > 6_100_000) throw new ClientError('Photo upload is too large.', 413);
        chunks.push(chunk);
      }
      let body;
      try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); }
      catch { throw new ClientError('Invalid JSON.'); }
      const submission = validateSubmission(body, now(), false);
      const cached = db.prepare('SELECT request_hash, response FROM submissions WHERE client=? AND id=?').get(client, submission.submissionId);
      if (cached) {
        if (cached.request_hash !== submission.requestHash) throw new ClientError('This submission ID was already used for different photos.', 409);
        return send(res, 200, JSON.parse(cached.response));
      }
      validateSubmission(body, now());
      lock = `${client}:${submission.submissionId}`;
      if (inFlight.has(lock)) { lock = undefined; throw new ClientError('This submission is already being checked. Retry shortly.', 409); }
      if (active >= 2) { lock = undefined; throw new ClientError('The server is busy. Retry shortly.', 429); }
      const bucketKey = req.socket.remoteAddress;
      const bucket = rate.get(bucketKey) ?? { since: now(), count: 0 };
      if (now() - bucket.since >= 60_000) { bucket.since = now(); bucket.count = 0; }
      if (++bucket.count > 6) { lock = undefined; throw new ClientError('Too many submissions. Wait one minute.', 429); }
      rate.set(bucketKey, bucket);
      for (const [key, value] of rate) if (now() - value.since > 120_000) rate.delete(key);
      const rewarded = db.prepare('SELECT COUNT(*) AS count FROM submissions WHERE client=? AND approved=1 AND created>?').get(client, now() - 86_400_000).count;
      if (rewarded >= 10) { lock = undefined; throw new ClientError('Daily reward limit reached. Try again tomorrow.', 429); }
      inFlight.add(lock); active++;
      const reused = submission.photos.some(photo => db.prepare('SELECT 1 FROM evidence WHERE digest=?').get(photo.digest));
      if (reused) throw new ClientError('A photo from this submission already earned a reward. Capture a new action.', 409);
      // Reserve before calling Gemini. Failures may still consume tokens, so never refund attempts.
      // This is shared by every installation using this database and survives restarts.
      db.exec('BEGIN IMMEDIATE');
      try {
        const cutoff = now() - 86_400_000;
        const used = db.prepare('SELECT COUNT(*) AS count FROM review_attempts WHERE created>?').get(cutoff).count;
        if (used >= dailyReviewLimit) throw new ClientError('The server’s daily AI review limit has been reached. Try later; no leaves were added.', 429);
        db.prepare('INSERT INTO review_attempts VALUES(?,?,?)').run(randomUUID(), client, now());
        db.prepare('DELETE FROM review_attempts WHERE created<=?').run(cutoff);
        db.exec('COMMIT');
      } catch (error) { db.exec('ROLLBACK'); throw error; }
      const assessment = await verify(submission.photos);
      const result = { ...decide(assessment, submission.submissionId), receiptId: randomUUID(), reviewedAt: new Date(now()).toISOString() };
      // Recheck inside the same transaction so simultaneous requests cannot reward the same photo twice.
      db.exec('BEGIN IMMEDIATE');
      try {
        if (result.status === 'approved') {
          const dailyCount = db.prepare('SELECT COUNT(*) AS count FROM submissions WHERE client=? AND approved=1 AND created>?').get(client, now() - 86_400_000).count;
          if (dailyCount >= 10) throw new ClientError('Daily reward limit reached. Try again tomorrow.', 429);
          for (const photo of submission.photos) {
            if (db.prepare('SELECT 1 FROM evidence WHERE digest=?').get(photo.digest)) throw new ClientError('These photos already earned leaves.', 409);
            db.prepare('INSERT INTO evidence(digest,created) VALUES(?,?)').run(photo.digest, now());
          }
        }
        db.prepare('INSERT INTO submissions VALUES(?,?,?,?,?,?)').run(client, submission.submissionId, submission.requestHash, JSON.stringify(result), result.status === 'approved' ? 1 : 0, now());
        db.exec('COMMIT');
      } catch (error) { db.exec('ROLLBACK'); throw error; }
      return send(res, 200, result);
    } catch (error) {
      return send(res, error instanceof ClientError ? error.status : 500, { error: error instanceof ClientError ? error.message : 'Verification failed. No reward was issued; try again.' });
    } finally {
      if (lock && inFlight.delete(lock)) active--;
    }
  });
  server.requestTimeout = 70_000;
  server.headersTimeout = 15_000;
  server.once('close', () => db.close());
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {

  const server = createVerificationServer({
    token: process.env.ECOGOTCHI_ACCESS_TOKEN,
    verify: process.env.GEMINI_API_KEY ? createGeminiVerifier({ apiKey: process.env.GEMINI_API_KEY, model: process.env.GEMINI_MODEL || 'gemini-3.8-flash',
      maxOutputTokens: Number(process.env.GEMINI_MAX_OUTPUT_TOKENS ?? 2048) }) : null,
    dailyReviewLimit: Number(process.env.DAILY_REVIEW_LIMIT ?? 30),
    databasePath: process.env.DATABASE_PATH || './data/verification.sqlite'
  });
  server.listen({ port: Number(process.env.PORT || 8787), host: process.env.HOST || '127.0.0.1', ipv6Only: false }, () => {
    console.log(`EcoGotchi server ready on port ${process.env.PORT || 8787}. Community bin photos are stored in SQLite; AI review photos are transient.`);
  });
}
