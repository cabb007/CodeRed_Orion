import React, { useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, ActivityIndicator, AppState, Image, Linking, Platform, ScrollView, Switch, View } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { Asset } from 'expo-asset';
import { ImageManipulator, SaveFormat } from 'expo-image-manipulator';
import { File } from 'expo-file-system';
import { setAudioModeAsync, useAudioPlayer } from 'expo-audio';
import * as Haptics from 'expo-haptics';
import { useGame, uuid } from './GameProvider';
import { assess, buildSubmission, connection, STEPS } from './verification';
import { Settings } from './Panels';
import { art, Button, colors, Label, Panel, Sprite, styles } from './ui';

import ScanOverlay from './ScanOverlay';
import { useReduceMotion } from './sceneHooks';

const TITLES = ['Your bin', 'Your item', 'Disposal'];
const INSTRUCTIONS = [
  'Show the bin and its opening. Include any sorting icons, labels, or nearby signs.',
  'Show one item clearly, including material markings. Keep the same bin nearby.',
  'Show the same item entering the same bin. Use the timer or ask someone to help. Never reach inside.',
];
const deleteFile = uri => { if (Platform.OS !== 'web' && uri?.startsWith('file:')) { try { new File(uri).delete(); } catch {} } };
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

export default function Recycling({ sample = false, rewardPreview = false, onClose, onBusy }) {
  const store = useGame();
  const reduceMotion = useReduceMotion();
  const [scanFrame, setScanFrame] = useState(null);
  const [permission, requestPermission] = useCameraPermissions();
  const camera = useRef(null);
  const framesRef = useRef([]);
  const files = useRef(new Set());
  const id = useRef(uuid());
  const generation = useRef(0);
  const mounted = useRef(true);
  const busyRef = useRef(false);
  const controller = useRef(null);
  const pendingResult = useRef(null);
  const [mode, setMode] = useState(store.isDeveloperMode ? 'demo' : store.preferences.mode);
  const [cameraKey, setCameraKey] = useState(0);
  const [hasPendingReceipt, setHasPendingReceipt] = useState(false);
  const [frames, setFrames] = useState([]);
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [useTimer, setUseTimer] = useState(false);
  const [error, setError] = useState('');
  const [scanned, setScanned] = useState('');
  const [result, setResult] = useState(rewardPreview ? { demo: true, preview: true, rewardOnly: true, leaves: 0, cleanup: 0 } : null);
  const [showSettings, setShowSettings] = useState(false);
  const [inspecting, setInspecting] = useState(null);
  const [active, setActive] = useState(AppState.currentState === 'active');
  const binSound = useAudioPlayer(require('../assets/scan-bin.wav'));
  const itemSound = useAudioPlayer(require('../assets/scan-item.wav'));
  const disposalSound = useAudioPlayer(require('../assets/scan-disposal.wav'));
  const step = frames.length;
  const demo = mode === 'demo';

  const setWorking = value => { busyRef.current = value; if (mounted.current) setBusy(value); onBusy(value); };
  const releasePhotos = () => { files.current.forEach(deleteFile); files.current.clear(); };
  const restart = () => {
    generation.current++; setScanFrame(null); releasePhotos(); framesRef.current = []; id.current = uuid(); pendingResult.current = null;
    setCameraKey(key => key + 1); setHasPendingReceipt(false);
    setFrames([]); setResult(null); setError(''); setScanned(''); setReady(false); setCountdown(0);
  };
  useEffect(() => {
    mounted.current = true;
    setAudioModeAsync({ playsInSilentMode: false, allowsRecording: false, shouldPlayInBackground: false }).catch(() => {});
    return () => { mounted.current = false; generation.current++; controller.current?.abort(); releasePhotos(); onBusy(false); };
  }, []);
  useEffect(() => {
    const subscription = AppState.addEventListener('change', state => {
      setActive(state === 'active');
      if (state !== 'active' && framesRef.current.length < 3) {
        generation.current++; framesRef.current = []; releasePhotos(); setFrames([]); setReady(false); setCountdown(0); setScanned('');
        setScanFrame(null); setError('The camera session ended. Start with your bin again.');
      }
    });
    return () => subscription.remove();
  }, []);

  const complete = async capturedFrames => {
    if (!mounted.current || !capturedFrames || capturedFrames.length !== 3) return;
    setError('');
    try {
      if (demo) {
        // Sample artwork can only be used in an isolated Dev Mode.
        if (sample && !store.isDeveloperMode) throw new Error('Sample captures require Dev Mode.');
        if (!sample) buildSubmission(id.current, capturedFrames, { demo: true });
        const before = store.game.litter;
        const beforePoints = store.game.points;
        const applied = await store.recordDemo(id.current);
        if (mounted.current) {
          setResult({ demo: true, preview: store.isDeveloperMode, leaves: applied.applied ? applied.game.points - beforePoints : 0,
            cleanup: Math.max(0, before - applied.game.litter), duplicate: !applied.applied });
          releasePhotos(); framesRef.current = []; setFrames([]);
        }
      } else {
        const config = connection(store.preferences.url, store.token);
        controller.current = new AbortController();
        const receipt = pendingResult.current || await assess(config, buildSubmission(id.current, capturedFrames), store.installationId, controller.current.signal);
        if (!mounted.current) return;
        // Keep this receipt in memory on a save failure so retry never spends another AI attempt.
        pendingResult.current = receipt;
        setHasPendingReceipt(true);
        let applied;
        if (receipt.status === 'approved') applied = await store.recordReview(receipt);
        if (mounted.current) {
          setResult({ ...receipt, duplicate: applied ? !applied.applied : false });
          releasePhotos(); framesRef.current = []; setFrames([]); pendingResult.current = null;
        }
      }
    } catch (failure) { if (mounted.current) setError(failure.message || 'The scan could not be saved. Retry here.'); }
  };

  const capture = async () => {
    if (busyRef.current || framesRef.current.length >= 3) return;
    setWorking(true); setError('');
    const epoch = generation.current;
    const index = framesRef.current.length;
    try {
      if (useTimer && index === 2 && !sample) {
        for (let seconds = 3; seconds > 0; seconds--) {
          setCountdown(seconds); await pause(1000);
          if (!mounted.current || epoch !== generation.current) return;
        }
        setCountdown(0);
      }
      let photo;
      // Timestamp describes capture, not the later image preparation.
      const capturedAt = new Date().toISOString();
      if (sample) photo = { uri: Asset.fromModule([art.Thriving, require('../assets/sprites.png'), art.Tarnished][index]).uri, data: '' };
      else {
        if (!ready || !camera.current) throw new Error('Wait for the camera to be ready.');
        const original = await camera.current.takePictureAsync({ quality: 0.8, skipProcessing: false });
        if (!original?.uri) throw new Error('The photo could not be captured. Try again.');
        files.current.add(original.uri);
        if (!mounted.current || epoch !== generation.current) { deleteFile(original.uri); return; }
        const context = ImageManipulator.manipulate(original.uri);
        const size = Math.max(original.width, original.height);
        if (size > 1200) context.resize(original.width >= original.height ? { width: 1200 } : { height: 1200 });
        const image = await context.renderAsync();
        try {
          const resized = await image.saveAsync({ format: SaveFormat.JPEG, compress: 0.7, base64: true });
          photo = { uri: resized.uri, data: resized.base64 };
          files.current.add(photo.uri);
        } finally { image.release(); context.release(); deleteFile(original.uri); files.current.delete(original.uri); }
        if (!photo.data || photo.data.length > 2_000_000) throw new Error('The photo is too large. Try a fresh capture.');
      }
      if (!mounted.current || epoch !== generation.current) { deleteFile(photo.uri); return; }
      if (!demo && framesRef.current.some(f => f.data === photo.data)) throw new Error('Take a different photo for this step.');
      setScanFrame(photo.uri);
      await pause(650);
      if (!mounted.current || epoch !== generation.current) return;
      const next = [...framesRef.current, { ...photo, role: STEPS[index], capturedAt }];
      framesRef.current = next;
      const message = `Successfully scanned ${STEPS[index]}`;
      setScanned(message); AccessibilityInfo.announceForAccessibility(message);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      if (store.preferences.sound) {
        const player = [binSound, itemSound, disposalSound][index];
        try { await player.seekTo(0); player.play(); } catch {}
      }
      await pause(900);
      if (!mounted.current || epoch !== generation.current) return;
      setScanned('');
      if (next.length === 3 && demo) await complete(next);
    } catch (failure) { if (mounted.current) { setScanFrame(null); setError(failure.message || 'Capture failed. Try again.'); } }
    finally { if (mounted.current) setCountdown(0); setWorking(false); }
  };

  if (showSettings) return <Settings onDone={() => { setMode(store.isDeveloperMode ? 'demo' : store.preferences.mode); restart(); setShowSettings(false); }} />;
  if (inspecting !== null) return <View style={[styles.stack, { flex: 1 }]}>
    <Label style={styles.heading}>{TITLES[inspecting]}</Label><Image source={{ uri: frames[inspecting].uri }} style={{ flex: 1, minHeight: 300 }} resizeMode="contain" />
    <Button secondary onPress={() => setInspecting(null)}>Back to scan</Button>
  </View>;
  if (result) return <ScrollView contentContainerStyle={[styles.stack, { paddingBottom: 24 }]}>
    <Sprite name={result.leaves > 0 ? 'fern' : 'pip'} size={110} style={{ alignSelf: 'center' }} />
    <Label style={styles.heading}>{result.duplicate ? 'Already collected!' : result.demo ? 'Scan complete!' : result.status === 'approved' ? 'AI review passed!' : result.localAcceptance === 'unknown' ? 'Bin rules unclear' : 'This action did not qualify'}</Label>
    <Panel style={{ backgroundColor: colors.sage }}><Label style={styles.subheading}>{result.duplicate ? 'This action already earned leaves' : `${result.leaves} leaves${result.preview ? ' (temporary)' : ' earned'}`}</Label></Panel>
    {result.demo ? <Label>{result.rewardOnly ? 'Display only. No leaves or progress were changed.' : result.preview ? 'Dev Mode scans change only your temporary progress.' : 'All three captures were accepted in demo mode. Your progress is saved on this phone.'}</Label> : <>
      <Label>{result.itemName} · {result.material}</Label><Label>{result.explanation}</Label>
      <Panel style={{ gap: 8 }}><Label style={styles.subheading}>Sorting tip</Label><Label>{result.tip}</Label><Label style={styles.caption}>Bin evidence: {result.labelEvidence}</Label></Panel>
      <Label style={styles.caption}>{result.limitation}</Label>
    </>}
    <Button onPress={onClose}>Back to my habitat</Button>{!rewardPreview && <Button secondary onPress={restart}>Start a new scan</Button>}
  </ScrollView>;

  return <View style={{ flex: 1 }}>
    <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={[styles.stack, { paddingBottom: 20 }]}>
      <View style={[styles.row, { justifyContent: 'space-between', flexWrap: 'wrap' }]}><Label style={styles.subheading}>{store.isDeveloperMode ? 'Preview scan' : demo ? 'Demo scan · +20 leaves' : 'AI photo review'}</Label>
        <Button secondary disabled={busy || frames.length > 0} onPress={() => setShowSettings(true)}>Settings</Button></View>
      <View style={styles.row}>{TITLES.map((title, i) => <Label key={title} style={[styles.caption, { flex: 1, fontWeight: i === step ? '800' : '400' }]}>{frames.length > i ? '✓' : i + 1} {title}</Label>)}</View>
      {!demo && !store.preferences.url && <Panel style={styles.stack}><Label>Connect your review server before capturing an action.</Label><Button onPress={() => setShowSettings(true)}>Set up AI connection</Button></Panel>}
      {step < 3 ? <>
        <Label style={styles.heading}>{TITLES[step]}</Label><Label>{INSTRUCTIONS[step]}</Label>
        <View style={{ height: 300, backgroundColor: colors.forest, overflow: 'hidden', borderRadius: 5 }}>
          {sample ? <><Image source={[art.Thriving, require('../assets/sprites.png'), art.Tarnished][step]} resizeMode="contain" style={{ width: '100%', height: '100%' }} />
            <Label style={{ position: 'absolute', bottom: 8, alignSelf: 'center', backgroundColor: colors.paper, padding: 8 }}>SAMPLE ARTWORK</Label></>
            : permission?.granted && active ? <CameraView key={cameraKey} ref={camera} facing="back" mode="picture"
              onCameraReady={() => { setReady(true); setError(''); }} onMountError={event => { setReady(false); setError(event.message || 'The camera could not start.'); }} style={{ flex: 1 }} />
              : <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24, gap: 16 }}>
                <Label style={{ color: colors.paper, textAlign: 'center' }}>{active ? 'Camera permission is needed to capture your recycling action.' : 'Return to the app to start the camera.'}</Label>
                {active && <Button secondary onPress={() => permission?.canAskAgain === false ? Linking.openSettings() : requestPermission()}>{permission?.canAskAgain === false ? 'Open phone settings' : 'Allow camera'}</Button>}
              </View>}
          {!!scanFrame && <ScanOverlay uri={scanFrame} demo={demo} success={scanned} reduceMotion={reduceMotion} />}
          {!!countdown && <Label style={{ position: 'absolute', alignSelf: 'center', top: 110, color: '#ffffff', fontSize: 60, lineHeight: 80, fontWeight: '800' }}>{countdown}</Label>}
          {!!scanned && <Panel style={{ position: 'absolute', bottom: 16, left: 12, right: 12, backgroundColor: colors.gold }}><Label style={{ textAlign: 'center', fontWeight: '700' }}>{scanned}</Label></Panel>}
        </View>
        {step === 2 && !sample && <View style={styles.row}><Label style={{ flex: 1 }}>3-second shutter timer</Label><Switch accessibilityLabel="3-second shutter timer" disabled={busy} value={useTimer} onValueChange={setUseTimer} /></View>}
        <Label style={styles.caption}>{demo ? 'Photos stay on your phone. Demo does not classify their contents.' : 'Finish within 10 minutes. Check this bin’s sorting rules before depositing your item.'}</Label>
      </> : <>
        <Label style={styles.heading}>{demo ? 'Ready to collect' : 'Ready for one review'}</Label>
        <View style={styles.row}>{frames.map((frame, i) => <View key={frame.role} style={{ flex: 1, gap: 6 }}>
          <Image source={{ uri: frame.uri }} resizeMode="contain" style={{ width: '100%', height: 100, backgroundColor: colors.sage }} />
          <Button secondary disabled={busy} onPress={() => setInspecting(i)}>{TITLES[i]}</Button>
        </View>)}</View>
        {!demo && <Label style={styles.caption}>Send for review uploads these three photos to your server and Google Gemini. Avoid faces and personal details. The live preview is never uploaded. AI reviews visible evidence, not proof of downstream recycling.</Label>}
      </>}
      {!!error && <Label accessibilityLiveRegion="polite" style={styles.error}>{error}</Label>}
      {busy && <View style={styles.row}><ActivityIndicator color={colors.forest} /><Label>{countdown ? 'Get ready…' : step === 3 ? 'Finishing your scan…' : 'Capturing…'}</Label></View>}
    </ScrollView>
    <View style={{ gap: 8, paddingTop: 10, paddingBottom: 6, borderTopWidth: 1, borderColor: colors.sage }}>
      <Button disabled={busy || (!sample && step < 3 && (!ready || !active)) || (!demo && !store.preferences.url)} onPress={step < 3 ? capture : async () => {
        if (busyRef.current) return;
        setWorking(true); try { await complete(framesRef.current); } finally { setWorking(false); }
      }}>{busy ? countdown ? `Capturing in ${countdown}…` : 'Please wait…' : step < 3 ? sample ? 'Capture sample' : `Capture ${STEPS[step]}` : demo ? 'Collect leaves' : hasPendingReceipt ? 'Save reviewed reward' : 'Send for review'}</Button>
      {frames.length > 0 && <Button secondary disabled={busy} onPress={restart}>Start over</Button>}
    </View>
  </View>;
}
