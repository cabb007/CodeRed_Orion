import { ANIMALS, DECORATIONS, FOODS, HABITATS } from './catalog.js';
export { ANIMALS, DECORATIONS, FOODS, HABITATS } from './catalog.js';
export const POLLUTION_INTERVAL = 4 * 60 * 60 * 1000;
export const DEMO_LEAVES = 20;
export const REWARDS = Object.freeze({ aluminum:30, steel:25, plastic:20, glass:20, cardboard:15, paper:10, other:0, unknown:0 });
const habitatIDs = HABITATS.map(h => h.id);
const record = v => v !== null && typeof v === 'object' && !Array.isArray(v);
const natural = (v, max = Number.MAX_SAFE_INTEGER) => Number.isSafeInteger(v) && v >= 0 && v <= max;
export const habitatID = game => game.habitatID || 'grove';
export const habitatActions = game => game.actions.filter(a => (a.habitatID || 'grove') === habitatID(game));
export const condition = litter => litter === 0 ? 'Thriving' : litter <= 2 ? 'Littered' : litter <= 4 ? 'Tarnished' : 'Polluted';
export const health = game => Math.max(0, 100 - game.litter * 15);
export const unlockedAnimals = game => ANIMALS.filter(a => a.habitat === habitatID(game) && habitatActions(game).length >= a.required);
export const residentAnimals = game => unlockedAnimals(game).filter(a => game.litter < 5 || a.required === 0);
export const foodCount = (game, id) => game.foodInventory?.[id] || 0;
export const placement = (game, id) => game.decorationPlacements?.[id] || { locked:false };
// Original storage key/version remain readable. New fields are additive; old actions belong to the grove.
export function newGame(now = Date.now()) {
  return { version:1, points:0, litter:3, actions:[], ownedDecorations:[], lastPollution:now,
    habitatID:'grove', otherHabitats:{}, foodInventory:{}, petMeals:{}, decorationPlacements:{} };
}
export function decodeGame(raw) {
  const g = JSON.parse(raw);
  const progressValid = p => record(p) && natural(p.litter,6) && Number.isFinite(p.lastPollution);
  const mapValid = (m,ids,validate) => m === undefined || (record(m) && Object.entries(m).every(([id,value]) => ids.includes(id) && validate(value)));
  if (!record(g) || g.version !== 1 || !natural(g.points) || !progressValid(g) ||
    !Array.isArray(g.actions) || !Array.isArray(g.ownedDecorations) ||
    g.ownedDecorations.some(id => !DECORATIONS.some(d => d.id === id)) ||
    (g.habitatID !== undefined && !habitatIDs.includes(g.habitatID)) ||
    g.actions.some(a => !record(a) || typeof a.id !== 'string' || typeof a.item !== 'string' ||
      !Number.isFinite(Date.parse(a.date)) || !natural(a.reward,100) ||
      (a.habitatID !== undefined && !habitatIDs.includes(a.habitatID))) ||
    !mapValid(g.otherHabitats,habitatIDs,progressValid) ||
    !mapValid(g.foodInventory,FOODS.map(f => f.id),n => natural(n,99)) ||
    !mapValid(g.petMeals,ANIMALS.map(a => a.id),n => natural(n,999999)) ||
    !mapValid(g.decorationPlacements,DECORATIONS.map(d => d.id),p => record(p) && typeof p.locked === 'boolean' &&
      ((p.x === undefined && p.y === undefined) || [p.x,p.y].every(n => Number.isFinite(n) && n >= 0 && n <= 1)))) {
    throw new Error('The saved habitat could not be read. Your saved data has been kept.');
  }
  return { ...g, habitatID:habitatID(g), otherHabitats:g.otherHabitats || {}, foodInventory:g.foodInventory || {},
    petMeals:g.petMeals || {}, decorationPlacements:g.decorationPlacements || {} };
}
export function advance(game, now = Date.now(), interval = POLLUTION_INTERVAL) {
  if (!Number.isFinite(interval) || interval <= 0 || !Number.isFinite(now)) return game;
  const elapsed = now - game.lastPollution;
  if (elapsed < interval) return game;
  return { ...game, litter:Math.min(6,game.litter + Math.min(6,Math.floor(elapsed / interval))), lastPollution:now - (elapsed % interval) };
}
export function selectHabitat(game,destination,now = Date.now()) {
  if (!habitatIDs.includes(destination) || destination === habitatID(game)) return game;
  const previous = advance(game,now);
  const progress = game.otherHabitats?.[destination] || {litter:3,lastPollution:now};
  return advance({ ...previous, ...progress, habitatID:destination, otherHabitats:{
    ...game.otherHabitats, [habitatID(game)]:{litter:previous.litter,lastPollution:previous.lastPollution},
  } },now);
}
export function purchase(game,id) {
  const item = DECORATIONS.find(d => d.id === id && d.habitat === habitatID(game));
  if (!item || game.ownedDecorations.includes(id) || game.points < item.cost) return game;
  return {...game,points:game.points - item.cost,ownedDecorations:[...game.ownedDecorations,id]};
}
export function buyFood(game,id) {
  const food = FOODS.find(f => f.id === id && f.habitats.includes(habitatID(game)));
  if (!food || game.points < food.cost || foodCount(game,id) >= 99) return game;
  return {...game,points:game.points - food.cost,foodInventory:{...game.foodInventory,[id]:foodCount(game,id) + 1}};
}
export function feedPet(game,animalID,foodID,includeSheltering = false) {
  const food = FOODS.find(f => f.id === foodID && f.habitats.includes(habitatID(game)));
  const available = includeSheltering ? unlockedAnimals(game) : residentAnimals(game);
  if (!food || !foodCount(game,foodID) || !available.some(a => a.id === animalID)) return game;
  return {...game,foodInventory:{...game.foodInventory,[foodID]:foodCount(game,foodID) - 1},
    petMeals:{...game.petMeals,[animalID]:Math.min(999999,(game.petMeals?.[animalID] || 0) + 1)}};
}
const ownsHere = (game,id) => game.ownedDecorations.includes(id) && DECORATIONS.some(d => d.id === id && d.habitat === habitatID(game));
export function moveDecoration(game,id,x,y) {
  if (!ownsHere(game,id) || placement(game,id).locked || !Number.isFinite(x) || !Number.isFinite(y)) return game;
  return {...game,decorationPlacements:{...game.decorationPlacements,[id]:{
    ...placement(game,id),x:Math.max(0,Math.min(1,x)),y:Math.max(0,Math.min(1,y))}}};
}
export function lockDecoration(game,id,locked) {
  if (!ownsHere(game,id) || typeof locked !== 'boolean') return game;
  return {...game,decorationPlacements:{...game.decorationPlacements,[id]:{...placement(game,id),locked}}};
}
export function resetLayout(game) {
  return {...game,decorationPlacements:Object.fromEntries(Object.entries(game.decorationPlacements || {}).filter(([id]) =>
    !DECORATIONS.some(d => d.id === id && d.habitat === habitatID(game))))};
}
export function validReward(result) {
  return result?.status === 'approved' && REWARDS[result.material] > 0 && result.leaves === REWARDS[result.material] &&
    result.cleanup === 1 && result.verification === 'gemini_visual_review' && result.evidenceQuality === 'high' &&
    result.localAcceptance === 'recyclable_here' && ['printed_label','material_icon','nearby_sign'].includes(result.acceptanceEvidence) &&
    typeof result.itemName === 'string' && result.itemName.trim().length > 0 && result.itemName.length <= 120;
}
export function reward(game,{submissionId,receiptId,item,leaves,cleanup = 1,material,tip,source,id,now = Date.now()}) {
  if (!submissionId || !id || !natural(leaves,100) || (leaves === 0 && source !== 'preview') ||
    game.actions.some(a => a.submissionId === submissionId || (receiptId && a.receiptId === receiptId))) return game;
  return {...game,points:game.points + leaves,litter:Math.max(0,game.litter - Math.max(0,Math.min(6,cleanup))),
    actions:[...game.actions,{id,submissionId,...(receiptId ? {receiptId} : {}),item,reward:leaves,habitatID:habitatID(game),
      date:new Date(now).toISOString(),source,...(material ? {material} : {}),...(tip ? {tip} : {})}]};
}
export const developerDefaults = () => ({pausePollution:true,interval:POLLUTION_INTERVAL,actionReward:20,cleanup:1,
  animateAnimals:true,animateHabitat:true,showAtmosphere:true,showLabels:false,showGrid:false,ignoreRetreat:false,spriteScale:1,hiddenAnimals:[]});
export function previewActionCount(game,count,now = Date.now()) {
  const amount = Math.max(0,Math.min(30,Math.floor(count)));
  if (!Number.isFinite(amount)) return game;
  const current = habitatActions(game).slice(0,amount);
  while (current.length < amount) current.push({id:`preview-${habitatID(game)}-${now}-${current.length}`,item:'[Preview] Recycling',
    date:new Date(now).toISOString(),reward:20,source:'preview',habitatID:habitatID(game)});
  return {...game,actions:[...game.actions.filter(a => (a.habitatID || 'grove') !== habitatID(game)),...current]};
}
