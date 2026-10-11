import { validateDraft, UUID } from './communityBins.js';
export function createBinRepository({storage,photos}) {
  const key = 'ecogotchi.community-bin-drafts.v1'; let queue = Promise.resolve();
  const list = async () => {
    const raw = await storage.getItem(key); const items = raw ? JSON.parse(raw) : [];
    if (!Array.isArray(items) || items.some(b => !UUID.test(b?.id) || typeof b.photoURI !== 'string')) throw new Error('Saved bin landmarks could not be read.');
    return items;
  };
  const run = action => { const result = queue.then(action); queue = result.catch(() => {}); return result; };
  return {list:() => queue.then(list),
    save:draft => run(async () => {
      const bin = validateDraft(draft), all = await list(), old = all.find(b => b.id === bin.id);
      if (old) return old;
      if (all.length >= 50) throw new Error('Remove an old phone landmark before saving more (limit 50).');
      const photoURI = await photos.save(bin.id,bin.photo.data);
      const {photo,...metadata} = bin; const record = {...metadata,photoURI,capturedAt:photo.capturedAt};
      try { await storage.setItem(key,JSON.stringify([...all,record])); } catch (e) { await photos.remove(photoURI).catch(() => {}); throw e; }
      return record;
    }),
    read:record => photos.read(record.photoURI).then(data => ({...record,photo:{source:'camera',capturedAt:record.capturedAt,data}})),
    published:(id,shared,server) => run(async () => { const all = await list(); await storage.setItem(key,JSON.stringify(all.map(b => b.id === id ? {...b,shared,server} : b))); }),
    remove:id => run(async () => { const all = await list(), item = all.find(b => b.id === id); await storage.setItem(key,JSON.stringify(all.filter(b => b.id !== id))); if (item) await photos.remove(item.photoURI).catch(() => {}); }),
  };
}
