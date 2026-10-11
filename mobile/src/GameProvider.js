import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import { AppState, Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SecureStore from 'expo-secure-store';
import * as Crypto from 'expo-crypto';
import { advance, buyFood, decodeGame, DEMO_LEAVES, developerDefaults, feedPet, foodCount, habitatID,
  lockDecoration, moveDecoration, newGame, purchase, resetLayout, reward, selectHabitat, validReward } from './game';
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
  const [preferences, setPreferences] = useState({mode:'demo',sound:true,url:''});
  const [token, setToken] = useState('');
  const [installationId, setInstallationId] = useState('');
  const [preview, setPreview] = useState(null);
  const [developer, setDeveloper] = useState(developerDefaults);
  const [selectedFood, setSelectedFood] = useState(null);
  const repository = useRef(null);
  const previewRef = useRef(null);
  const developerRef = useRef(developer);
  const initialize = async () => {
    try {
      const loaded = await loadGame({read:key => AsyncStorage.getItem(key),decode:decodeGame,fresh:newGame});
      const next = advance(loaded.game);
      repository.current = createGameRepository({initial:next,decode:decodeGame,read:key => AsyncStorage.getItem(key),
        write:(key,value) => AsyncStorage.setItem(key,value),publish:setGame});
      await AsyncStorage.setItem(SAVE_KEY,JSON.stringify(next));
      await repository.current.backup();
      const raw = await AsyncStorage.getItem(PREFS_KEY);
      const saved = raw ? JSON.parse(raw) : {};
      const prefs = {mode:saved.mode === 'ai' ? 'ai' : 'demo',sound:saved.sound !== false,url:typeof saved.url === 'string' ? saved.url : ''};
      const savedToken = Platform.OS === 'web' ? '' : (await SecureStore.getItemAsync(TOKEN_KEY)) || '';
      let install = await AsyncStorage.getItem(INSTALL_KEY);
      if (!install) { install = uuid(); await AsyncStorage.setItem(INSTALL_KEY,install); }
      setPreferences(prefs); setToken(savedToken); setInstallationId(install); setGame(next); setError(null);
      if (loaded.recovered) setNotice('Your habitat was restored from its previous backup.');
    } catch (failure) { setError(failure.message || 'Saved progress could not be loaded.'); }
  };
  useEffect(() => { void Promise.resolve().then(initialize); }, []);
  useEffect(() => {
    const refresh = () => {
      if (previewRef.current) {
        if (!developerRef.current.pausePollution) {
          const next = advance(previewRef.current,Date.now(),developerRef.current.interval);
          previewRef.current = next; setPreview(next);
        }
      } else if (repository.current) repository.current.update(g => advance(g)).catch(() => setNotice('Progress could not be saved. Please retry.'));
    };
    const timer = setInterval(refresh,1000);
    const subscription = AppState.addEventListener('change',state => { if (state === 'active') refresh(); });
    return () => { clearInterval(timer); subscription.remove(); };
  }, []);
  const visible = preview || game;
  const availableFood = visible && selectedFood && foodCount(visible,selectedFood) ? selectedFood : null;
  const mutate = async transform => {
    if (previewRef.current) {
      const before = previewRef.current;
      const next = transform(before);
      decodeGame(JSON.stringify(next));
      previewRef.current = next; setPreview(next);
      return {applied:next !== before,game:next};
    }
    if (!repository.current) throw new Error('Wait for your habitat to load.');
    let applied = false;
    const result = await repository.current.update(g => {
      const advanced = advance(g); const next = transform(advanced); applied = next !== advanced; return next;
    });
    repository.current.backup().catch(() => setNotice('Progress saved; the backup could not be updated.'));
    return {...result,applied};
  };
  const savePreferences = async (next,newToken = token) => {
    if (Platform.OS === 'web' && next.mode === 'ai') throw new Error('Use Expo Go on your phone for AI review. The browser preview is demo-only.');
    if (Platform.OS !== 'web') await SecureStore.setItemAsync(TOKEN_KEY,newToken);
    await AsyncStorage.setItem(PREFS_KEY,JSON.stringify(next));
    setPreferences(next); setToken(newToken);
  };
  const recordDemo = submissionId => mutate(g => reward(g,{
    id:uuid(),submissionId,item:previewRef.current ? '[Preview] Recycling demo' : 'Recycling demo',
    leaves:previewRef.current ? developerRef.current.actionReward : DEMO_LEAVES,
    cleanup:previewRef.current ? developerRef.current.cleanup : 1,source:previewRef.current ? 'preview' : 'demo',
  }));
  const recordReview = result => {
    if (previewRef.current || !validReward(result)) throw new Error('This review cannot award leaves.');
    return mutate(g => reward(g,{id:uuid(),submissionId:result.submissionId.toLowerCase(),receiptId:result.receiptId.toLowerCase(),
      item:result.itemName,leaves:result.leaves,cleanup:result.cleanup,material:result.material,tip:result.tip,source:'ai'}));
  };
  const configureDeveloper = update => {
    if (!previewRef.current) return;
    const next = {...developerRef.current,...update};
    developerRef.current = next; setDeveloper(next);
  };
  const resetDeveloper = () => { const next = developerDefaults(); developerRef.current = next; setDeveloper(next); setSelectedFood(null); };
  const beginPreview = () => {
    if (previewRef.current || !repository.current) return;
    resetDeveloper();
    const copy = JSON.parse(JSON.stringify(advance(repository.current.get())));
    previewRef.current = copy; setPreview(copy);
  };
  const endPreview = async () => {
    previewRef.current = null; setPreview(null); resetDeveloper();
    await repository.current.update(g => advance(g));
  };
  const reset = async () => {
    try {
      await AsyncStorage.multiRemove([SAVE_KEY,BACKUP_KEY]);
      previewRef.current = null; setPreview(null); resetDeveloper(); await initialize();
    } catch (failure) { setError(failure.message); }
  };
  const switchHabitat = async id => { const result = await mutate(g => selectHabitat(g,id)); setSelectedFood(null); return result; };
  return <GameContext.Provider value={{game:visible,loaded:!!game && !error,error,notice,dismissNotice:() => setNotice(''),
    preferences,token,installationId,savePreferences,recordDemo,recordReview,
    buy:id => mutate(g => purchase(g,id)),buyFood:id => mutate(g => buyFood(g,id)),selectedFood:availableFood,setSelectedFood,
    feed:(animalID,foodID) => mutate(g => feedPet(g,animalID,foodID,!!previewRef.current && developerRef.current.ignoreRetreat)),
    moveDecoration:(id,x,y) => mutate(g => moveDecoration(g,id,x,y)),
    lockDecoration:(id,locked) => mutate(g => lockDecoration(g,id,locked)),
    resetLayout:() => mutate(resetLayout),switchHabitat,
    isPreview:!!preview,developer:preview ? developer : developerDefaults(),configureDeveloper,beginPreview,endPreview,
    editPreview:transform => previewRef.current ? mutate(transform) : Promise.resolve({applied:false}),
    reset,retry:initialize,reportError:failure => setNotice(failure?.message || 'Could not save. Please retry.'),
    habitat:visible ? habitatID(visible) : 'grove'}}>
    {children}
  </GameContext.Provider>;
}
export const useGame = () => useContext(GameContext);
