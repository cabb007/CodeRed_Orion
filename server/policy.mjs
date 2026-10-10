import { createHash } from 'node:crypto';

export const REWARDS = Object.freeze({ aluminum: 30, steel: 25, plastic: 20, glass: 20, cardboard: 15, paper: 10, other: 0, unknown: 0 });
export const MATERIALS = Object.keys(REWARDS);
export const ACCEPTANCE_EVIDENCE = ['printed_label', 'material_icon', 'nearby_sign', 'none'];
export const MAX_AGE_MS = 10 * 60_000;
export class ClientError extends Error {
  constructor(message, status = 400) { super(message); this.status = status; }
}
export const hash = bytes => createHash('sha256').update(bytes).digest('hex');

export function validateSubmission(body, now = Date.now(), checkFresh = true) {
  if (!body || typeof body !== 'object' || !/^[a-f0-9-]{36}$/i.test(body.submissionId ?? '')) throw new ClientError('Invalid submission ID.');
  if (!Array.isArray(body.photos) || body.photos.length !== 3) throw new ClientError('Capture the bin, item, and disposal action.');
  const expected = ['bin', 'item', 'disposal'];
  let previous = -Infinity;
  const photos = body.photos.map((photo, index) => {
    if (!photo || photo.role !== expected[index] || photo.source !== 'camera' || photo.mimeType !== 'image/jpeg') throw new ClientError('Rewards require three fresh camera photos in order.');
    const captured = Date.parse(photo.capturedAt);
    if (!Number.isFinite(captured) || (checkFresh && (captured < now - MAX_AGE_MS || captured > now + 30_000)) || captured <= previous) throw new ClientError('Photos expired or are out of order. Start a new capture.');
    previous = captured;
    if (typeof photo.data !== 'string' || photo.data.length > 2_000_000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(photo.data)) throw new ClientError('Invalid photo data.');
    const bytes = Buffer.from(photo.data, 'base64');
    if (bytes.length < 100 || bytes.length > 1_500_000 || bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) throw new ClientError('Photo must be a JPEG under 1.5 MB.');
    return { ...photo, digest: hash(bytes) };
  });
  if (new Set(photos.map(p => p.digest)).size !== 3) throw new ClientError('Use a different capture for each step.');
  return { submissionId: body.submissionId.toLowerCase(), photos, requestHash: hash(JSON.stringify(photos.map(p => [p.role, p.capturedAt, p.digest]))) };
}

const string = (value, max) => typeof value === 'string' && value.trim().length > 0 && value.length <= max;
export function validateAssessment(a) {
  if (!a || !MATERIALS.includes(a.material) || !string(a.itemName, 120) || !string(a.explanation, 800) || !string(a.tip, 500) ||
      !['high', 'medium', 'low'].includes(a.evidenceQuality) ||
      !['recyclable_here', 'not_accepted_here', 'unknown'].includes(a.localAcceptance) ||
      !ACCEPTANCE_EVIDENCE.includes(a.acceptanceEvidence) ||
      !string(a.labelEvidence, 300)) throw new ClientError('The AI returned an incomplete assessment. Please retry.', 502);
  for (const key of ['sameItem', 'sameBin', 'disposalVisible', 'contaminated', 'suspicious']) {
    if (typeof a[key] !== 'boolean') throw new ClientError('The AI returned an invalid assessment. Please retry.', 502);
  }
  return a;
}

export function decide(assessment, submissionId) {
  const a = validateAssessment(assessment);
  // A model's confident guess cannot substitute for visible bin-specific rules.
  const localAcceptance = a.acceptanceEvidence === 'none' ? 'unknown' : a.localAcceptance;
  let status = 'needs_review';
  if (a.suspicious || a.contaminated || localAcceptance === 'not_accepted_here') status = 'rejected';
  else if (a.evidenceQuality === 'high' && localAcceptance === 'recyclable_here' &&
           a.sameItem && a.sameBin && a.disposalVisible && REWARDS[a.material] > 0) status = 'approved';
  return {
    submissionId, status, itemName: a.itemName, material: a.material,
    leaves: status === 'approved' ? REWARDS[a.material] : 0,
    cleanup: status === 'approved' ? 1 : 0,
    explanation: status === 'needs_review' && localAcceptance === 'unknown'
      ? 'We couldn’t establish what this bin accepts from the photos. This doesn’t mean your recycling was incorrect.'
      : a.explanation,
    tip: a.tip, labelEvidence: a.labelEvidence, localAcceptance, acceptanceEvidence: a.acceptanceEvidence,
    evidenceQuality: a.evidenceQuality, verification: 'gemini_visual_review',
    // These are visual plausibility checks, not proof of downstream recycling.
    limitation: 'AI reviewed the photos. It cannot prove collection or downstream recycling.'
  };
}
