export const POLLUTION_INTERVAL = 4 * 60 * 60 * 1000;
export const DEMO_LEAVES = 20;
export const REWARDS = Object.freeze({ aluminum: 30, steel: 25, plastic: 20, glass: 20, cardboard: 15, paper: 10, other: 0, unknown: 0 });
export const ANIMALS = [
  { id: 'pip', name: 'Pip', required: 0, detail: 'Your very first woodland friend.' },
  { id: 'fern', name: 'Fern', required: 1, detail: 'A little frog with a big love for clean ponds.' },
  { id: 'clover', name: 'Clover', required: 3, detail: 'Always looking for a peaceful patch of grass.' },
  { id: 'maple', name: 'Maple', required: 6, detail: 'A shy visitor who loves a healthy grove.' },
];
export const DECORATIONS = [
  { id: 'flowers', name: 'Wildflowers', cost: 40 },
  { id: 'mushrooms', name: 'Mushroom nook', cost: 60 },
  { id: 'house', name: 'Little hideaway', cost: 100 },
];

export function newGame(now = Date.now()) {
  return { version: 1, points: 0, litter: 3, actions: [], ownedDecorations: [], lastPollution: now };
}
export function decodeGame(raw) {
  const game = JSON.parse(raw);
  if (game?.version !== 1 || !Number.isSafeInteger(game.points) || game.points < 0 ||
      !Number.isInteger(game.litter) || game.litter < 0 || game.litter > 6 ||
      !Number.isFinite(game.lastPollution) || !Array.isArray(game.actions) ||
      !Array.isArray(game.ownedDecorations) ||
      game.ownedDecorations.some(id => !DECORATIONS.some(d => d.id === id)) ||
      game.actions.some(a => !a || typeof a.id !== 'string' || typeof a.item !== 'string' ||
        !Number.isFinite(Date.parse(a.date)) || !Number.isInteger(a.reward) || a.reward < 0 || a.reward > 100)) {
    throw new Error('The saved grove could not be read. Your saved data has been kept.');
  }
  return game;
}
export const condition = litter => litter === 0 ? 'Thriving' : litter <= 2 ? 'Littered' : litter <= 4 ? 'Tarnished' : 'Polluted';
export const health = game => Math.max(0, 100 - game.litter * 15);
export const unlockedAnimals = game => ANIMALS.filter(a => game.actions.length >= a.required);
export function advance(game, now = Date.now(), interval = POLLUTION_INTERVAL) {
  if (!Number.isFinite(interval) || interval <= 0 || !Number.isFinite(now)) return game;
  const elapsed = now - game.lastPollution;
  if (elapsed < interval) return game;
  return { ...game, litter: Math.min(6, game.litter + Math.min(6, Math.floor(elapsed / interval))), lastPollution: now - (elapsed % interval) };
}
export function purchase(game, id) {
  const item = DECORATIONS.find(d => d.id === id);
  if (!item || game.ownedDecorations.includes(id) || game.points < item.cost) return game;
  return { ...game, points: game.points - item.cost, ownedDecorations: [...game.ownedDecorations, id] };
}
export function validReward(result) {
  return result?.status === 'approved' && REWARDS[result.material] > 0 && result.leaves === REWARDS[result.material] &&
    result.cleanup === 1 && result.verification === 'gemini_visual_review' && result.evidenceQuality === 'high' &&
    result.localAcceptance === 'recyclable_here' && ['printed_label', 'material_icon', 'nearby_sign'].includes(result.acceptanceEvidence) &&
    typeof result.itemName === 'string' && result.itemName.trim().length > 0 && result.itemName.length <= 120;
}
export function reward(game, { submissionId, receiptId, item, leaves, cleanup = 1, material, tip, source, id, now = Date.now() }) {
  if (!submissionId || !id || !Number.isInteger(leaves) || leaves <= 0 || leaves > 100 ||
      game.actions.some(a => a.submissionId === submissionId || (receiptId && a.receiptId === receiptId))) return game;
  return {
    ...game, points: game.points + leaves, litter: Math.max(0, game.litter - Math.max(0, Math.min(6, cleanup))),
    actions: [...game.actions, { id, submissionId, ...(receiptId ? { receiptId } : {}), item, reward: leaves,
      date: new Date(now).toISOString(), source, ...(material ? { material } : {}), ...(tip ? { tip } : {}) }],
  };
}
