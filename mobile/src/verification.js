import { validReward } from './game.js';

export const STEPS = ['bin', 'item'];
export const MAX_AGE = 10 * 60 * 1000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function buildSubmission(id, frames, { demo = false, now = Date.now() } = {}) {
  if (!UUID.test(id) || frames.length !== STEPS.length) throw new Error('Capture your bin and item first.');
  let previous = -Infinity;
  const seen = new Set();
  const photos = frames.map((frame, index) => {
    const captured = Date.parse(frame.capturedAt);
    if (frame.role !== STEPS[index] || !Number.isFinite(captured) || captured <= previous ||
        (!demo && (captured < now - MAX_AGE || captured > now + 30_000))) {
      throw new Error('The photos expired or are out of order. Start a new capture.');
    }
    previous = captured;
    if (typeof frame.data !== 'string' || frame.data.length < 136 || frame.data.length > 2_000_000 ||
        !/^[A-Za-z0-9+/]+={0,2}$/.test(frame.data) || !frame.data.startsWith('/9j/')) throw new Error('Capture a JPEG photo under 1.5 MB.');
    if (!demo && seen.has(frame.data)) throw new Error('Use a different photo for each step.');
    seen.add(frame.data);
    return { role: frame.role, source: 'camera', mimeType: 'image/jpeg', capturedAt: frame.capturedAt, data: frame.data };
  });
  return { submissionId: id, photos };
}

export function connection(address, accessToken) {
  let url;
  try { url = new URL(address.trim()); } catch { throw new Error('Enter your review server’s HTTPS address.'); }
  // HTTPS works in Expo Go without changing its native transport settings.
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || (url.pathname !== '/' && url.pathname !== '')) {
    throw new Error('Use an HTTPS server address with no path. A local server needs an HTTPS tunnel.');
  }
  const token = accessToken.trim();
  if (token.length < 24) throw new Error('Use RECYCLI_ACCESS_TOKEN (at least 24 characters), not the Gemini key.');
  return { url: url.origin, token };
}

export function validateReceipt(result, submissionId) {
  if (!result || result.submissionId?.toLowerCase() !== submissionId.toLowerCase() || !UUID.test(result.receiptId) ||
      !Number.isFinite(Date.parse(result.reviewedAt)) || !['approved', 'needs_review', 'rejected'].includes(result.status) ||
      ['itemName', 'tip', 'explanation', 'labelEvidence', 'limitation'].some(key => typeof result[key] !== 'string') ||
      (result.status === 'approved' ? !validReward(result) : (result.leaves !== 0 || result.cleanup !== 0))) {
    throw new Error('The server returned an incomplete review. No leaves were added.');
  }
  return result;
}

async function request(config, path, { body, installationId, signal, timeout = 12_000, fetchImpl = fetch } = {}) {
  const controller = new AbortController();
  const cancel = () => controller.abort();
  if (signal?.aborted) controller.abort();
  signal?.addEventListener('abort', cancel);
  const timer = setTimeout(cancel, timeout);
  try {
    const response = await fetchImpl(`${config.url}${path}`, {
      method: body ? 'POST' : 'GET', redirect: 'error', signal: controller.signal,
      headers: { Authorization: `Bearer ${config.token}`, ...(body ? { 'Content-Type': 'application/json', 'X-Installation-ID': installationId } : {}) },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    if (response.redirected || (response.url && new URL(response.url).origin !== config.url)) throw new Error('Use the server’s direct HTTPS address; redirects are not supported.');
    if (response.status === 401) throw new Error('The server access token did not match. Check Scan settings.');
    let result;
    try { result = await response.json(); } catch { throw new Error('The server did not return a valid review response.'); }
    if (!response.ok) throw new Error(result.error || `Review server returned ${response.status}. Try again.`);
    return result;
  } catch (error) {
    if (controller.signal.aborted) throw new Error(signal?.aborted ? 'Review cancelled.' : 'Connection timed out. Retry the same photos while this screen is open.');
    if (error instanceof TypeError) throw new Error('Could not reach the server. Check its HTTPS address and your connection.');
    throw error;
  } finally { clearTimeout(timer); signal?.removeEventListener('abort', cancel); }
}
export async function testConnection(config, options) {
  const result = await request(config, '/v1/status', options);
  if (!['recycli','ecogotchi'].includes(result.service) || result.status !== 'ok' || !Number.isInteger(result.reviewsRemaining) || result.reviewsRemaining < 0) {
    throw new Error('This address did not return a valid Recycli connection check.');
  }
  return result;
}
export async function assess(config, submission, installationId, signal) {
  const result = await request(config, '/v1/recycling/verify', { body: submission, installationId, signal, timeout: 60_000 });
  return validateReceipt(result, submission.submissionId);
}
