import AsyncStorage from '@react-native-async-storage/async-storage';
import { createBinRepository } from './binRepository';
import { UUID } from './communityBins';
const validKey = key => { if (!key.startsWith('ecogotchi.bin-photo.') || !UUID.test(key.slice('ecogotchi.bin-photo.'.length))) throw new Error('Invalid saved photo key.'); return key; };
export const binRepository = createBinRepository({storage:AsyncStorage,photos:{
  save:async (id,data) => { const key = 'ecogotchi.bin-photo.' + id; await AsyncStorage.setItem(key,data); return key; },
  read:async key => { const data = await AsyncStorage.getItem(validKey(key)); if (!data) throw new Error('The saved photo is missing.'); return data; },
  remove:key => AsyncStorage.removeItem(validKey(key)),
}});
