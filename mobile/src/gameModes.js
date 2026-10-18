// A mode session owns its actions. Callbacks from an abandoned session cannot write.
export function createGameModes({ repository, decode, advance, getPreferences, preferencesIdle, publish, initialSessionId = 0, onBackupError = () => {} }) {
  let sessionId = initialSessionId, sandbox = null, changing = false;
  const snapshot = () => ({ sessionId, isDeveloperMode:!!sandbox, changing,
    game:sandbox?.game || repository.get(), preferences:sandbox?.preferences || getPreferences() });
  const notify = () => publish(snapshot());
  const assertCurrent = id => {
    if (changing || id !== sessionId) throw new Error('The mode changed. Please repeat this action in the current mode.');
  };
  return {
    snapshot, refresh:notify, assertCurrent,
    assertReal(id) { assertCurrent(id); if (sandbox) throw new Error('Turn off Dev Mode to change saved landmarks or make real purchases.'); },
    async setEnabled(enabled) {
      if (typeof enabled !== 'boolean') throw new Error('Choose whether Dev Mode is on or off.');
      if (changing) throw new Error('Wait for the mode switch to finish.');
      if (!!sandbox === enabled) return;
      changing = true; sessionId++; notify();
      try {
        // Include every accepted real save before taking the temporary copy.
        await Promise.all([repository.idle(),preferencesIdle()]);
        sandbox = enabled ? {game:JSON.parse(JSON.stringify(advance(repository.get()))),
          preferences:{...getPreferences(),mode:'demo'}} : null;
      } finally { changing = false; notify(); }
    },
    async update(id,transform) {
      assertCurrent(id);
      if (sandbox) {
        const before = sandbox.game, next = transform(before);
        decode(JSON.stringify(next)); sandbox.game = next; notify();
        return {applied:next !== before,game:next};
      }
      let applied = false;
      const result = await repository.update(g => {
        const before = advance(g), next = transform(before); applied = next !== before; return next;
      });
      repository.backup().catch(onBackupError);
      return {...result,applied};
    },
    setTemporaryPreferences(id,next) {
      assertCurrent(id); if (!sandbox) return false;
      sandbox.preferences = {...next,mode:'demo'}; notify(); return true;
    },
    tick(options) {
      if (changing) return;
      if (sandbox) { if (!options.pausePollution) { sandbox.game = advance(sandbox.game,Date.now(),options.interval); notify(); } }
      else return repository.update(g => advance(g));
    },
  };
}
