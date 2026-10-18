import { bounded } from './motion.js';
import { MAX_HABITAT_ANIMALS } from './habitatResidents.js';
// One shared world per habitat. Reserve the full sprite plus room for bobbing,
// lifting and tilting; transparent atlas padding is deliberately conservative.
export function createAnimalWorld() {
  const animals = new Map(), listeners = new Map();
  const overlaps = (a,b) => Math.abs(a.body.x - b.body.x) < a.half + b.half + 2 && Math.abs(a.body.y - b.body.y) < a.halfY + b.halfY + 2;
  const place = (id,body,bounds,size) => {
    if (!animals.has(id) && animals.size >= MAX_HABITAT_ANIMALS) throw new Error('A habitat can have at most four animals.');
    const entry = {body:{...body,...bounded(body,bounds)},half:size * .78,halfY:size * .78 + 8,bounds};
    const others = [...animals.entries()].filter(([key]) => key !== id).map(([,a]) => a);
    const free = p => others.every(a => !overlaps({...entry,body:p},a));
    let chosen = entry.body;
    if (!free(chosen)) {
      // Separate animals sideways while preserving their requested height.
      // Upward projection can trap a resident forever in the falling branch.
      const xs = [chosen.x,bounds.left,bounds.right];
      for (const other of others) {
        const gapX = entry.half + other.half + 2.01;
        xs.push(other.body.x - gapX,other.body.x + gapX);
      }
      const candidates = xs.map(x => ({x,y:chosen.y})).filter(p => p.x >= bounds.left && p.x <= bounds.right && free(p))
        .sort((a,b) => (a.x - chosen.x) ** 2 + (a.y - chosen.y) ** 2 - (b.x - chosen.x) ** 2 - (b.y - chosen.y) ** 2);
      const previous = animals.get(id)?.body;
      const destination = candidates[0] || (previous && free(previous) && previous.y === chosen.y ? previous : null);
      if (destination) chosen = {...body,...destination,vx:0,vy:0,grounded:body.grounded && destination.y === bounds.bottom};
      else {
        // A central animal can leave two unusable gaps. Repack the row instead
        // of accepting an overlap; update every moved animal's physics body.
        const group = [...others,entry].sort((a,b) => a.body.x - b.body.x);
        let edge = -Infinity; const packed = [];
        for (const item of group) {
          const x = Math.max(item.bounds.left,edge + item.half + 2.01);
          packed.push({item,x}); edge = x + item.half;
        }
        if (packed.every(p => p.x <= p.item.bounds.right)) {
          const shift = Math.max(0,Math.min(...packed.map(p => p.item.bounds.right - p.x)) / 2);
          for (const {item,x} of packed) {
            item.body = {...item.body,x:x + shift,vx:0};
            if (item === entry) chosen = item.body;
            else { const key = [...animals.entries()].find(([,a]) => a === item)?.[0]; listeners.get(key)?.(item.body); }
          }
        }
      }
    }
    entry.body = chosen; animals.set(id,entry); return chosen;
  };
  return {move:place,listen:(id,listener) => { listeners.set(id,listener); return () => listeners.delete(id); },
    remove:id => { animals.delete(id); listeners.delete(id); },snapshot:() => [...animals.entries()].map(([id,a]) => ({id,...a.body,half:a.half,halfY:a.halfY}))};
}
