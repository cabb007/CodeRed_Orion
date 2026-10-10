export const SAVE_KEY = 'ecogotchi.mobile.v1';
export const BACKUP_KEY = `${SAVE_KEY}.backup`;

// Mutations use this queue so a slow write never overwrites a newer reward or purchase.
// Publish only after durable storage succeeds; on failure the caller can retry.
export function createGameRepository({ read, write, decode, initial, publish }) {
  let current = initial;
  let tail = Promise.resolve();
  return {
    get: () => current,
    update(transform) {
      const operation = tail.then(async () => {
        const next = transform(current);
        if (next === current) return { applied: false, game: current };
        const raw = JSON.stringify(next);
        decode(raw);
        await write(SAVE_KEY, raw);
        current = next;
        publish(next);
        return { applied: true, game: next };
      });
      tail = operation.catch(() => {});
      return operation;
    },
    async backup() { await write(BACKUP_KEY, JSON.stringify(current)); },
  };
}

export async function loadGame({ read, decode, fresh }) {
  const raw = await read(SAVE_KEY);
  if (!raw) return { game: fresh(), recovered: false };
  try { return { game: decode(raw), recovered: false }; }
  catch (error) {
    const backup = await read(BACKUP_KEY);
    if (!backup) throw error;
    try { return { game: decode(backup), recovered: true }; } catch { throw error; }
  }
}
