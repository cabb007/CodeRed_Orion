import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import { AppState, Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SecureStore from 'expo-secure-store';
import * as Crypto from 'expo-crypto';
import { advance, decodeGame, DEMO_LEAVES, newGame, purchase, reward, validReward } from './game';
import { BACKUP_KEY, createGameRepository, loadGame, SAVE_KEY } from './storage';

const GameContext = createContext(null);
const PREFS_KEY = 'ecogotchi.mobile.preferences';
const TOKEN_KEY = 'ecogotchi.mobile.token';
const INSTALL_KEY = 'ecogotchi.mobile.installation';
export const uuid = () => Crypto.randomUUID();

export function GameProvider({ children }) {
  const [game, setGame] = useState(null);
  const [error, setError] = useState(null);
  const [notice, setNotice] = useState('');
  const [preferences, setPreferences] = useState({ mode: 'demo', sound: true, url: '' });
  const [token, setToken] = useState('');
  const [installationId, setInstallationId] = useState('');
  const [preview, setPreview] = useState(null);
  const repository = useRef(null);
  const previewRef = useRef(null);
  const preferencesRef = useRef(preferences);

  const initialize = async () => {
    try {
      const loaded = await loadGame({ read: key => AsyncStorage.getItem(key), decode: decodeGame, fresh: newGame });
      setError(null);
      const next = advance(loaded.game);
      repository.current = createGameRepository({ initial: next, decode: decodeGame,
        read: key => AsyncStorage.getItem(key), write: (key, value) => AsyncStorage.setItem(key, value), publish: setGame });
      await AsyncStorage.setItem(SAVE_KEY, JSON.stringify(next));
      await repository.current.backup();
      const rawPrefs = await AsyncStorage.getItem(PREFS_KEY);
      const savedPrefs = rawPrefs ? JSON.parse(rawPrefs) : {};
      const prefs = { mode: savedPrefs.mode === 'ai' ? 'ai' : 'demo', sound: savedPrefs.sound !== false,
        url: typeof savedPrefs.url === 'string' ? savedPrefs.url : '' };
      const savedToken = Platform.OS === 'web' ? '' : (await SecureStore.getItemAsync(TOKEN_KEY)) || '';
      let install = await AsyncStorage.getItem(INSTALL_KEY);
      if (!install) { install = uuid(); await AsyncStorage.setItem(INSTALL_KEY, install); }
      preferencesRef.current = prefs;
      setPreferences(prefs); setToken(savedToken); setInstallationId(install); setGame(next);
      if (loaded.recovered) setNotice('Your grove was restored from its previous backup.');
    } catch (failure) { setError(failure.message || 'Saved progress could not be loaded.'); }
  };
  useEffect(() => { void Promise.resolve().then(initialize); }, []);
  useEffect(() => {
    const refresh = () => {
      if (repository.current && !previewRef.current) repository.current.update(g => advance(g)).catch(() => setNotice('Progress could not be saved. Please retry.'));
    };
    const timer = setInterval(refresh, 30_000);
    const subscription = AppState.addEventListener('change', state => { if (state === 'active') refresh(); });
    return () => { clearInterval(timer); subscription.remove(); };
  }, []);

  const mutate = async transform => {
    if (previewRef.current) {
      const next = transform(previewRef.current);
      const applied = next !== previewRef.current;
      previewRef.current = next; setPreview(next);
      return { applied, game: next };
    }
    const result = await repository.current.update(g => transform(advance(g)));
    // The main write has already committed. A failed backup must not make the UI say it failed.
    repository.current.backup().catch(() => setNotice('Progress saved; the backup could not be updated.'));
    return result;
  };
  const savePreferences = async (next, newToken = token) => {
    if (Platform.OS === 'web' && next.mode === 'ai') throw new Error('Use Expo Go on your iPhone for AI review. The browser preview is demo-only.');
    if (Platform.OS !== 'web') await SecureStore.setItemAsync(TOKEN_KEY, newToken);
    await AsyncStorage.setItem(PREFS_KEY, JSON.stringify(next));
    preferencesRef.current = next; setPreferences(next); setToken(newToken);
  };
  const applyReward = async transform => {
    let applied = false;
    const result = await mutate(g => { const next = transform(g); applied = next !== g; return next; });
    return { ...result, applied };
  };
  const recordDemo = submissionId => applyReward(g => reward(g, {
    id: uuid(), submissionId, item: previewRef.current ? '[Preview] Recycling demo' : 'Recycling demo',
    leaves: DEMO_LEAVES, source: previewRef.current ? 'preview' : 'demo',
  }));
  const recordReview = result => {
    if (previewRef.current || !validReward(result)) throw new Error('This review cannot award leaves.');
    return applyReward(g => reward(g, { id: uuid(), submissionId: result.submissionId.toLowerCase(), receiptId: result.receiptId.toLowerCase(),
      item: result.itemName, leaves: result.leaves, cleanup: result.cleanup, material: result.material, tip: result.tip, source: 'ai' }));
  };
  const beginPreview = () => {
    if (previewRef.current || !repository.current) return;
    const copy = JSON.parse(JSON.stringify(advance(repository.current.get())));
    previewRef.current = copy; setPreview(copy);
  };
  const endPreview = async () => {
    previewRef.current = null; setPreview(null);
    await repository.current.update(g => advance(g));
  };
  const reset = async () => {
    await AsyncStorage.multiRemove([SAVE_KEY, BACKUP_KEY]);
    previewRef.current = null; setPreview(null); await initialize();
  };
  return <GameContext.Provider value={{ game: preview || game, loaded: !!game && !error, error, notice, dismissNotice: () => setNotice(''),
    preferences, token, installationId, savePreferences, recordDemo, recordReview,
    buy: id => mutate(g => purchase(g, id)), isPreview: !!preview, beginPreview, endPreview,
    editPreview: transform => { if (previewRef.current) mutate(transform); }, reset, retry: initialize }}>
    {children}
  </GameContext.Provider>;
}
export const useGame = () => useContext(GameContext);
