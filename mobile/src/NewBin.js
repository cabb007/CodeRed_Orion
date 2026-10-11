import React, { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, AppState, Image, Linking, Platform, TextInput, View } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { ImageManipulator, SaveFormat } from 'expo-image-manipulator';
import { File } from 'expo-file-system';
import { useGame, uuid } from './GameProvider';
import { locate } from './deviceLocation';
import { BIN_MATERIALS, validateDraft } from './communityBins';
import { binRepository } from './binStorage';
import BinPlacement from './BinPlacement';
import { Button, Label, Panel, styles } from './ui';
const remove = uri => { if (Platform.OS !== 'web' && uri?.startsWith('file:')) { try { new File(uri).delete(); } catch {} } };
export default function NewBin({onSaved,onClose}) {
  const store = useGame();
  const [permission,requestPermission] = useCameraPermissions();
  const camera = useRef(null), mounted = useRef(true), controller = useRef(null), working = useRef(false), generation = useRef(0), id = useRef(uuid());
  const [photo,setPhoto] = useState(null), [name,setName] = useState(''), [notes,setNotes] = useState(''), [materials,setMaterials] = useState(['Unknown']);
  const [coordinate,setCoordinate] = useState(null), [latitude,setLatitude] = useState(''), [longitude,setLongitude] = useState('');
  const [publicAccess,setPublic] = useState(false), [positionConfirmed,setPositionConfirmed] = useState(false);
  const [busy,setBusy] = useState(false), [ready,setReady] = useState(false), [active,setActive] = useState(AppState.currentState === 'active'), [error,setError] = useState('');
  const position = c => { const next = {latitude:c.latitude,longitude:c.longitude}; setCoordinate(next); setLatitude(next.latitude.toFixed(5)); setLongitude(next.longitude.toFixed(5)); setPositionConfirmed(false); };
  useEffect(() => {
    mounted.current = true;
    const subscription = AppState.addEventListener('change',s => { setActive(s === 'active'); if (s !== 'active') { generation.current++; controller.current?.abort(); setReady(false); } });
    return () => { mounted.current = false; generation.current++; controller.current?.abort(); subscription.remove(); };
  },[]);
  const run = async action => {
    if (working.current) return; working.current = true; setBusy(true); setError('');
    try { await action(); } catch (e) { if (mounted.current) setError(e.message || 'Could not finish. Please retry.'); }
    finally { working.current = false; if (mounted.current) setBusy(false); }
  };
  const capture = () => run(async () => {
    const epoch = generation.current; let raw,rendered,context,saved;
    try {
      raw = await camera.current.takePictureAsync({quality:.8,skipProcessing:false});
      context = ImageManipulator.manipulate(raw.uri);
      const edge = Math.max(raw.width,raw.height); if (edge > 960) context.resize(raw.width >= raw.height ? {width:960} : {height:960});
      rendered = await context.renderAsync(); saved = await rendered.saveAsync({format:SaveFormat.JPEG,compress:.6,base64:true});
      if (!mounted.current || epoch !== generation.current) return;
      if (!saved.base64 || saved.base64.length > 500000) throw new Error('This photo is too large. Try again with a simpler view of the bin.');
      setPhoto({source:'camera',capturedAt:new Date().toISOString(),data:saved.base64});
    } finally { context?.release(); rendered?.release(); remove(raw?.uri); remove(saved?.uri); }
  });
  const locateBin = () => run(async () => { controller.current?.abort(); controller.current = new AbortController(); const c = await locate(controller.current.signal); if (mounted.current && !controller.current.signal.aborted) position(c); });
  const applyCoordinates = () => { const a = Number(latitude), b = Number(longitude); if (!latitude.trim() || !longitude.trim() || !Number.isFinite(a) || !Number.isFinite(b) || Math.abs(a) > 90 || Math.abs(b) > 180) { setError('Enter valid latitude and longitude.'); return; } position({latitude:a,longitude:b}); };
  const save = () => run(async () => {
    store.assertReal();
    if (!positionConfirmed) throw new Error('Confirm that the pin marks the bin.');
    const draft = validateDraft({id:id.current,name,notes,materials,coordinate,publicAccess,photo});
    const record = await binRepository.save(draft); if (mounted.current) onSaved(record);
  });
  return <Panel style={styles.stack}>
    <Label style={styles.heading}>Add a bin landmark</Label>
    <Label>Photograph a publicly accessible bin and its sorting label. Avoid people, private spaces, and identifying details. Nothing is uploaded when you take a photo.</Label>
    {!photo && <>
      {!permission?.granted ? <><Button onPress={() => requestPermission().catch(e => setError(e.message))}>Allow camera</Button>
        {permission && !permission.canAskAgain && Platform.OS !== 'web' && <Button secondary onPress={() => Linking.openSettings()}>Open phone settings</Button>}</> :
        <>{active && <CameraView ref={camera} facing="back" style={{height:270}} onCameraReady={() => setReady(true)} onMountError={() => setError('Could not open the camera. Check camera permission.')} />}
          <Button disabled={!active || !ready || busy} onPress={capture}>Photograph this bin</Button></>}
    </>}
    {photo && <><Image accessibilityLabel="Your bin photograph" source={{uri:'data:image/jpeg;base64,' + photo.data}} style={{height:220,width:'100%'}} resizeMode="contain" />
      <Button secondary disabled={busy} onPress={() => { setPhoto(null); setReady(false); }}>Retake photo</Button></>}
    <Button secondary disabled={busy} onPress={locateBin}>Use my location for the bin</Button>
    <Label style={styles.caption}>Move the pin to the bin itself. Location permission is requested only when you tap above.</Label>
    {coordinate && <BinPlacement coordinate={coordinate} onChange={position} />}
    <TextInput accessibilityLabel="Bin latitude" keyboardType="numbers-and-punctuation" value={latitude} onChangeText={v => { setLatitude(v); setPositionConfirmed(false); }} placeholder="Latitude" style={styles.input} />
    <TextInput accessibilityLabel="Bin longitude" keyboardType="numbers-and-punctuation" value={longitude} onChangeText={v => { setLongitude(v); setPositionConfirmed(false); }} placeholder="Longitude" style={styles.input} />
    <Button secondary onPress={applyCoordinates}>Apply coordinates</Button>
    <Button secondary disabled={!coordinate || busy} onPress={() => { applyCoordinates(); if (coordinate && +latitude === +coordinate.latitude.toFixed(5) && +longitude === +coordinate.longitude.toFixed(5)) setPositionConfirmed(true); }}>{positionConfirmed ? '✓ Position confirmed' : 'Confirm this pin marks the bin'}</Button>
    <TextInput accessibilityLabel="Bin landmark name" placeholder="e.g. Library recycling bin" value={name} maxLength={80} onChangeText={setName} style={styles.input} />
    <Label>Materials shown on its label</Label>
    <View style={[styles.row,{flexWrap:'wrap'}]}>{BIN_MATERIALS.map(m => <Button key={m} secondary={!materials.includes(m)} onPress={() => setMaterials(list => m === 'Unknown' ? ['Unknown'] : list.includes(m) ? list.filter(x => x !== m) : [...list.filter(x => x !== 'Unknown'),m])}>{m}</Button>)}</View>
    <TextInput accessibilityLabel="Bin landmark notes" placeholder="Where to find it, access times, or sorting instructions" multiline maxLength={500} value={notes} onChangeText={setNotes} style={styles.input} />
    <Button secondary onPress={() => setPublic(!publicAccess)}>{publicAccess ? '✓ Public access confirmed' : 'Confirm this bin is publicly accessible'}</Button>
    <Label style={styles.caption}>Save first, then choose Share with community from its map card. Sharing publishes this photo, exact bin position, name, and notes to other users connected to your server. No leaves are awarded.</Label>
    {!!error && <Label style={styles.error}>{error}</Label>}{busy && <ActivityIndicator />}
    <Button disabled={busy || !photo || !positionConfirmed || !publicAccess} onPress={save}>Save landmark on this phone</Button>
    <Button secondary disabled={busy} onPress={onClose}>Cancel</Button>
  </Panel>;
}
