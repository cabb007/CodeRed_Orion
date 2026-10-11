import AsyncStorage from '@react-native-async-storage/async-storage';
import { Directory, File, Paths } from 'expo-file-system';
import { createBinRepository } from './binRepository';
import { UUID } from './communityBins';
const directory = new Directory(Paths.document,'community-bins');
const savedFile = uri => {
  const prefix = directory.uri.replace(/\/$/,'') + '/';
  if (!uri.startsWith(prefix) || !UUID.test(uri.slice(prefix.length).replace(/\.jpg$/,'')) || !uri.endsWith('.jpg')) throw new Error('Invalid saved bin photo path.');
  return new File(uri);
};
export const binRepository = createBinRepository({storage:AsyncStorage,photos:{
  save:async (id,data) => { directory.create({idempotent:true,intermediates:true}); const file = new File(directory,id + '.jpg'); try { file.create({overwrite:true}); file.write(data,{encoding:'base64'}); return file.uri; } catch (e) { if (file.exists) file.delete(); throw e; } },
  read:async uri => savedFile(uri).base64(), remove:async uri => { const file = savedFile(uri); if (file.exists) file.delete(); },
}});
