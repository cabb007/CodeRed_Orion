// Resolves one position and always releases the native/browser subscription, including races.
export function firstPosition(subscribe, { signal, timeoutMs = 15000 } = {}) {
  return new Promise((resolve, reject) => {
    let done = false, subscription;
    const cancelled = () => { const error = new Error('Search cancelled.'); error.name = 'AbortError'; finish(null, error); };
    const finish = (value, error) => {
      if (done) return;
      done = true; clearTimeout(timer); signal?.removeEventListener('abort', cancelled);
      subscription?.remove();
      if (error) reject(error); else resolve(value);
    };
    const timer = setTimeout(() => finish(null, new Error('Location took too long. Try city or ZIP search.')), timeoutMs);
    signal?.addEventListener('abort', cancelled);
    if (signal?.aborted) { cancelled(); return; }
    try {
      Promise.resolve(subscribe(value => finish(value), error => finish(null, error))).then(
        sub => { if (done) sub?.remove(); else subscription = sub; },
        error => finish(null, error),
      );
    } catch (error) { finish(null, error); }
  });
}
