import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import { AppState, Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SecureStore from 'expo-secure-store';
import * as Crypto from 'expo-crypto';
import { advance, buyFood, decodeGame, DEMO_LEAVES, developerDefaults, feedPet, foodCount, habitatID,
  lockDecoration, moveDecoration, newGame, purchase, resetLayout, reward, selectHabitat, validReward } from './game';
import { BACKUP_KEY, createGameRepository, loadGame, SAVE_KEY } from './storage';
import { createGameModes } from './gameModes';
const GameContext = createContext(null);
const PREFS_KEY = 'ecogotchi.mobile.preferences';
const TOKEN_KEY = 'ecogotchi.mobile.token';
const INSTALL_KEY = 'ecogotchi.mobile.installation';
export const uuid = () => Crypto.randomUUID();
export function GameProvider({ children }) {
  const [game,setGame] = useState(null), [mode,setMode] = useState({sessionId:0,isDeveloperMode:false,changing:false});
  const [error,setError] = useState(null), [notice,setNotice] = useState('');
  const [token,setToken] = useState(''), [installationId,setInstallationId] = useState('');
  const [developer,setDeveloper] = useState(developerDefaults), [selectedFood,setSelectedFood] = useState(null);
  const repository = useRef(null), modes = useRef(null), developerRef = useRef(developer);
  const preferences = useRef({mode:'demo',sound:true,url:''}), preferencesTail = useRef(Promise.resolve());
  const initialize = async () => {
    try {
      const loaded = await loadGame({read:key => AsyncStorage.getItem(key),decode:decodeGame,fresh:newGame});
      const next = advance(loaded.game);
      repository.current = createGameRepository({initial:next,decode:decodeGame,
        write:(key,value) => AsyncStorage.setItem(key,value),publish:next => { setGame(next); modes.current?.refresh(); }});
      await AsyncStorage.setItem(SAVE_KEY,JSON.stringify(next));
      await repository.current.backup();
      const raw = await AsyncStorage.getItem(PREFS_KEY), saved = raw ? JSON.parse(raw) : {};
      preferences.current = {mode:saved.mode === 'ai' ? 'ai' : 'demo',sound:saved.sound !== false,url:typeof saved.url === 'string' ? saved.url : ''};
      const savedToken = Platform.OS === 'web' ? '' : (await SecureStore.getItemAsync(TOKEN_KEY)) || '';
      let install = await AsyncStorage.getItem(INSTALL_KEY);
      if (!install) { install = uuid(); await AsyncStorage.setItem(INSTALL_KEY,install); }
      modes.current = createGameModes({repository:repository.current,decode:decodeGame,advance,
        getPreferences:() => preferences.current,preferencesIdle:() => preferencesTail.current,publish:setMode,
        initialSessionId:(modes.current?.snapshot().sessionId || 0) + 1,
        onBackupError:() => setNotice('Progress saved; the backup could not be updated.')});
      modes.current.refresh(); setToken(savedToken); setInstallationId(install); setGame(next); setError(null);
      if (loaded.recovered) setNotice('Your habitat was restored from its previous backup.');
    } catch (failure) { setError(failure.message || 'Saved progress could not be loaded.'); }
  };
  useEffect(() => { void Promise.resolve().then(initialize); },[]);
  useEffect(() => {
    const refresh = () => { Promise.resolve(modes.current?.tick(developerRef.current)).catch(() => setNotice('Progress could not be saved. Please retry.')); };
    const timer = setInterval(refresh,1000);
    const subscription = AppState.addEventListener('change',state => { if (state === 'active') refresh(); });
    return () => { clearInterval(timer); subscription.remove(); };
  },[]);
  // Context actions capture the session that rendered them, including delayed callbacks.
  const sessionId = mode.sessionId, isDeveloperMode = mode.isDeveloperMode;
  const visible = mode.game || game;
  const assertCurrent = () => modes.current?.assertCurrent(sessionId);
  const assertReal = () => { if (!modes.current) throw new Error('Wait for your habitat to load.'); modes.current.assertReal(sessionId); };
  const mutate = transform => {
    if (!modes.current) throw new Error('Wait for your habitat to load.');
    return modes.current.update(sessionId,transform);
  };
  const savePreferences = async (next,newToken = token) => {
    assertCurrent();
    if (modes.current.setTemporaryPreferences(sessionId,next)) return;
    if (Platform.OS === 'web' && next.mode === 'ai') throw new Error('Use the phone app for AI review. The browser preview is demo-only.');
    const operation = preferencesTail.current.then(async () => {
      if (Platform.OS !== 'web') await SecureStore.setItemAsync(TOKEN_KEY,newToken);
      await AsyncStorage.setItem(PREFS_KEY,JSON.stringify(next));
      preferences.current = next; setToken(newToken); modes.current.refresh();
    });
    preferencesTail.current = operation.catch(() => {});
    await operation;
  };
  const configureDeveloper = update => {
    assertCurrent(); if (!isDeveloperMode) return;
    const next = {...developerRef.current,...update}; developerRef.current = next; setDeveloper(next);
  };
  const setDeveloperMode = async enabled => {
    assertCurrent();
    await modes.current.setEnabled(enabled);
    const next = developerDefaults(); developerRef.current = next; setDeveloper(next); setSelectedFood(null);
  };
  const recordDemo = submissionId => mutate(g => reward(g,{id:uuid(),submissionId,
    item:isDeveloperMode ? '[Dev Mode] Recycling demo' : 'Recycling demo',
    leaves:isDeveloperMode ? developerRef.current.actionReward : DEMO_LEAVES,
    cleanup:isDeveloperMode ? developerRef.current.cleanup : 1,source:isDeveloperMode ? 'preview' : 'demo'}));
  const recordReview = result => {
    assertReal(); if (!validReward(result)) throw new Error('This review cannot award leaves.');
    return mutate(g => reward(g,{id:uuid(),submissionId:result.submissionId.toLowerCase(),receiptId:result.receiptId.toLowerCase(),
      item:result.itemName,leaves:result.leaves,cleanup:result.cleanup,material:result.material,tip:result.tip,source:'ai'}));
  };
  const reset = async () => {
    try {
      assertCurrent();
      if (isDeveloperMode) {
        configureDeveloper(developerDefaults()); setSelectedFood(null); await mutate(() => newGame()); return;
      }
      if (repository.current) {
        await repository.current.update(() => newGame());
        await repository.current.backup();
      } else await AsyncStorage.multiRemove([SAVE_KEY,BACKUP_KEY]);
      await initialize();
    } catch (failure) { setError(failure.message); }
  };
  const switchHabitat = async id => { const result = await mutate(g => selectHabitat(g,id)); assertCurrent(); setSelectedFood(null); return result; };
  const availableFood = visible && selectedFood && foodCount(visible,selectedFood) ? selectedFood : null;
  return <GameContext.Provider value={{game:visible,loaded:!!game && !error,error,notice,dismissNotice:() => setNotice(''),
    preferences:mode.preferences || {mode:'demo',sound:true,url:''},token:isDeveloperMode ? '' : token,installationId,
    savePreferences,recordDemo,recordReview,assertCurrent,assertReal,
    buy:id => mutate(g => purchase(g,id)),buyFood:id => mutate(g => buyFood(g,id)),selectedFood:availableFood,
    setSelectedFood:id => { assertCurrent(); setSelectedFood(id); },
    feed:(animalID,foodID) => mutate(g => feedPet(g,animalID,foodID,isDeveloperMode && developerRef.current.ignoreRetreat)),
    moveDecoration:(id,x,y) => mutate(g => moveDecoration(g,id,x,y)),lockDecoration:(id,locked) => mutate(g => lockDecoration(g,id,locked)),
    resetLayout:() => mutate(resetLayout),switchHabitat,isDeveloperMode,sessionId,modeChanging:mode.changing,
    developer:isDeveloperMode ? developer : developerDefaults(),configureDeveloper,setDeveloperMode,
    editDeveloper:transform => isDeveloperMode ? mutate(transform) : Promise.reject(new Error('Turn on Dev Mode first.')),
    reset,retry:initialize,reportError:failure => setNotice(failure?.message || 'Could not save. Please retry.'),
    habitat:visible ? habitatID(visible) : 'grove'}}>
    {children}
  </GameContext.Provider>;
}
export const useGame = () => useContext(GameContext);
