import { createHash } from 'node:crypto';

export const REWARDS = Object.freeze({ aluminum: 30, steel: 25, plastic: 20, glass: 20, cardboard: 15, paper: 10, other: 0, unknown: 0 });
export const MATERIALS = Object.keys(REWARDS);
export const ACCEPTANCE_EVIDENCE = ['printed_label', 'material_icon', 'nearby_sign', 'bin_appearance', 'none'];
export const MAX_AGE_MS = 10 * 60_000;
export class ClientError extends Error {
  constructor(message, status = 400) { super(message); this.status = status; }
}
export const hash = bytes => createHash('sha256').update(bytes).digest('hex');

export function validateSubmission(body, now = Date.now(), checkFresh = true) {
  if (!body || typeof body !== 'object' || !/^[a-f0-9-]{36}$/i.test(body.submissionId ?? '')) throw new ClientError('Invalid submission ID.');
  if (!Array.isArray(body.photos) || body.photos.length !== 2) throw new ClientError('Capture the bin and item.');
  const expected = ['bin', 'item'];
  let previous = -Infinity;
  const photos = body.photos.map((photo, index) => {
    if (!photo || photo.role !== expected[index] || photo.source !== 'camera' || photo.mimeType !== 'image/jpeg') throw new ClientError('Rewards require two fresh camera photos in order.');
    const captured = Date.parse(photo.capturedAt);
    if (!Number.isFinite(captured) || (checkFresh && (captured < now - MAX_AGE_MS || captured > now + 30_000)) || captured <= previous) throw new ClientError('Photos expired or are out of order. Start a new capture.');
    previous = captured;
    if (typeof photo.data !== 'string' || photo.data.length > 2_000_000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(photo.data)) throw new ClientError('Invalid photo data.');
    const bytes = Buffer.from(photo.data, 'base64');
    if (bytes.length < 100 || bytes.length > 1_500_000 || bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) throw new ClientError('Photo must be a JPEG under 1.5 MB.');
    return { ...photo, digest: hash(bytes) };
  });
  if (new Set(photos.map(p => p.digest)).size !== 2) throw new ClientError('Use a different capture for each step.');
  return { submissionId: body.submissionId.toLowerCase(), photos, requestHash: hash(JSON.stringify(photos.map(p => [p.role, p.capturedAt, p.digest]))) };
}

const string = (value, max) => typeof value === 'string' && value.trim().length > 0 && value.length <= max;
export function validateAssessment(a) {
  if (!a || !MATERIALS.includes(a.material) || !string(a.itemName, 120) || !string(a.explanation, 800) || !string(a.tip, 500) ||
      !['high', 'medium', 'low'].includes(a.evidenceQuality) ||
      !['recycling', 'general_waste', 'unknown'].includes(a.binType) ||
      !['recyclable_here', 'likely_compatible', 'not_accepted_here', 'unknown'].includes(a.localAcceptance) ||
      !ACCEPTANCE_EVIDENCE.includes(a.acceptanceEvidence) ||
      !string(a.labelEvidence, 300)) throw new ClientError('The AI returned an incomplete assessment. Please retry.', 502);
  for (const key of ['contaminated', 'suspicious']) {
    if (typeof a[key] !== 'boolean') throw new ClientError('The AI returned an invalid assessment. Please retry.', 502);
  }
  return a;
}

export function decide(assessment, submissionId) {
  const a = validateAssessment(assessment);
  // Appearance supports a likely match, never a claim about local collection rules.
  const localAcceptance = a.acceptanceEvidence === 'none' || a.binType === 'unknown' ? 'unknown'
    : a.acceptanceEvidence === 'bin_appearance' && a.localAcceptance === 'recyclable_here' ? 'likely_compatible'
    : a.localAcceptance;
  let status = 'needs_review';
  if (a.suspicious || a.contaminated || a.binType === 'general_waste' || localAcceptance === 'not_accepted_here') status = 'rejected';
  else if (a.evidenceQuality === 'high' && a.binType === 'recycling' && ['recyclable_here', 'likely_compatible'].includes(localAcceptance) &&
           REWARDS[a.material] > 0) status = 'approved';
  return {
    submissionId, status, itemName: a.itemName, material: a.material,
    leaves: status === 'approved' ? REWARDS[a.material] : 0,
    cleanup: status === 'approved' ? 1 : 0,
    explanation: status === 'needs_review' && localAcceptance === 'unknown'
      ? 'We couldn’t recognize a clear recycling match. Try a wider, sharper photo of the bin and its opening.'
      : a.explanation,
    tip: a.tip, labelEvidence: a.labelEvidence, localAcceptance, acceptanceEvidence: a.acceptanceEvidence, binType: a.binType,
    evidenceQuality: a.evidenceQuality, verification: 'gemini_visual_review',
    // These are visual plausibility checks, not proof of downstream recycling.
    limitation: 'Visual match only; local collection rules can differ. AI did not verify disposal or downstream recycling.'
  };
}
