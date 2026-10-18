import React, { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, Image, Linking, Platform, ScrollView, TextInput, View } from 'react-native';
import { locate as deviceLocation } from './deviceLocation';
import { useGame } from './GameProvider';
import BinMap from './BinMap';
import NewBin from './NewBin';
import BinConnection from './BinConnection';
import { binRepository } from './binStorage';
import { binRequest, findCommunity, mergeBins, shareBin } from './communityBins';
import { areaFor, createLocationService, directionsURL, distance, RADII } from './locations';
import { Button, Label, Panel, styles } from './ui';
const service = createLocationService();
export default function RecyclingFinder() {
  const store = useGame();
  const [query,setQuery] = useState(''), [radius,setRadius] = useState(5000), [area,setArea] = useState(null);
  const [result,setResult] = useState(null), [community,setCommunity] = useState([]), [local,setLocal] = useState([]);
  const [selected,setSelected] = useState(null), [photo,setPhoto] = useState(null), [adding,setAdding] = useState(false), [settings,setSettings] = useState(false);
  const [busy,setBusy] = useState(false), [sharing,setSharing] = useState(false), [error,setError] = useState(''), [denied,setDenied] = useState(false), [notice,setNotice] = useState('');
  const request = useRef(null), generation = useRef(0), mounted = useRef(true), upload = useRef(null), shareLock = useRef(false);
  const configured = Platform.OS !== 'web' && !!store.preferences.url && store.token.length >= 24;
  const cancel = () => { generation.current++; request.current?.abort(); request.current = null; };
  useEffect(() => { mounted.current = true; binRepository.list().then(items => { if (mounted.current) setLocal(items); }).catch(e => { if (mounted.current) setError(e.message); }); return () => { mounted.current = false; cancel(); upload.current?.abort(); }; },[]);
  const start = async work => {
    cancel(); const epoch = generation.current; request.current = new AbortController(); const signal = request.current.signal;
    setBusy(true); setError(''); setSelected(null);
    try { await work(signal,epoch); } catch (e) { if (generation.current === epoch && !signal.aborted) { setDenied(e.code === 'LOCATION_DENIED'); setError(e.message || 'Search failed. Check your connection.'); } }
    finally { if (mounted.current && generation.current === epoch) setBusy(false); }
  };
  const search = async (center,nextRadius,signal,epoch) => {
    const next = areaFor(center,nextRadius);
    if (signal.aborted || epoch !== generation.current) return;
    setArea(next); setResult(null); setCommunity([]);
    const outcomes = await Promise.allSettled([service.search(center,nextRadius,signal),binRepository.list(),configured ? findCommunity(store,next,signal) : Promise.resolve({bins:[]})]);
    if (signal.aborted || epoch !== generation.current) return;
    const [listed,saved,shared] = outcomes;
    setResult(listed.status === 'fulfilled' ? listed.value : {area:next,locations:[]});
    if (saved.status === 'fulfilled') setLocal(saved.value);
    if (shared.status === 'fulfilled') setCommunity(shared.value.bins);
    setError(outcomes.flatMap((o,i) => o.status === 'rejected' ? [(i === 2 ? 'Community map: ' : '') + o.reason.message] : []).join(' '));
    if (shared.status === 'fulfilled' && shared.value.truncated) setNotice('Showing the nearest 200 community bins. Search a smaller area for more detail.');
  };
  const locate = () => start(async (signal,epoch) => { const center = await deviceLocation(signal); if (!signal.aborted) setDenied(false); await search(center,radius,signal,epoch); });
  const findPlace = () => start(async (signal,epoch) => { const center = await service.geocode(query,signal); await search(center,radius,signal,epoch); });
  const chooseRadius = next => { setRadius(next); if (area) start((signal,epoch) => search(area,next,signal,epoch)); };
  const locations = area ? mergeBins(area,result?.locations || [],community,local,store.preferences.url) : [];
  const location = locations.find(l => l.id === selected);
  useEffect(() => {
    const controller = new AbortController();
    const load = async () => { setPhoto(null); if (!location?.hasPhoto) return;
      try {
        const draft = location.localId && local.find(b => b.id === location.localId);
        const data = draft ? (await binRepository.read(draft)).photo.data : configured ? (await binRequest(store.preferences.url,store.token,store.installationId,'/v1/bins/' + location.id + '/photo',{signal:controller.signal})).data : null;
        if (data && (typeof data !== 'string' || data.length > 500000 || !data.startsWith('/9j/'))) throw new Error('Invalid landmark photo.');
        if (!controller.signal.aborted) setPhoto(data ? 'data:image/jpeg;base64,' + data : null);
      } catch (e) { if (!controller.signal.aborted) setError(e.message); }
    };
    void load(); return () => controller.abort();
  },[selected,local,store.preferences.url,store.token,store.installationId,configured]); // Selection owns the photo request.
  const open = url => Linking.openURL(url).catch(() => setError('Could not open that link. Check your maps app or browser.'));
  const saved = async record => {
    const records = await binRepository.list();
    if (!mounted.current) return;
    cancel(); setBusy(false); setAdding(false); setLocal(records);
    const showSaved = () => {
      setSelected(record.id);
      setNotice('Landmark saved on this phone. Select Share with community to publish it.');
    };
    // A nearby draft joins the existing map without discarding public or shared pins.
    if (area && distance(area,record.coordinate) <= area.radius) {
      showSaved();
      return;
    }
    // For a first or distant landmark, load public listings around its location too.
    await start(async (signal,epoch) => {
      await search(record.coordinate,radius,signal,epoch);
      if (mounted.current && !signal.aborted && epoch === generation.current) showSaved();
    });
  };
  const share = async () => {
    if (shareLock.current) return; shareLock.current = true; setSharing(true); setError(''); upload.current = new AbortController();
    try {
      store.assertReal();
      const record = local.find(b => b.id === location.localId); const draft = await binRepository.read(record);
      const bin = await shareBin(store,draft,upload.current.signal);
      store.assertReal();
      await binRepository.published(record.id,bin,store.preferences.url);
      if (mounted.current) { setLocal(await binRepository.list()); setCommunity(list => [...list.filter(b => b.id !== bin.id),bin]); setSelected(bin.id); setNotice('Landmark shared. It is labeled Community · unverified.'); }
    } catch (e) { if (mounted.current) setError(e.message); } finally { shareLock.current = false; if (mounted.current) setSharing(false); }
  };
  const remove = async () => {
    try {
      store.assertReal();
      if (location.community) await binRequest(store.preferences.url,store.token,store.installationId,'/v1/bins/' + location.id,{method:'DELETE'});
      if (location.localId) await binRepository.remove(location.localId);
      setCommunity(list => list.filter(b => b.id !== location.id)); setLocal(await binRepository.list()); setSelected(null); setNotice('Landmark removed.');
    } catch (e) { setError(e.message); }
  };
  const confirmRemove = () => Platform.OS === 'web' ? (globalThis.confirm('Remove this phone landmark?') && remove()) : Alert.alert('Remove landmark?',location.community ? 'This removes your landmark and photo from the shared map.' : 'This removes the saved landmark and photo from this phone.',[{text:'Cancel',style:'cancel'},{text:'Remove',style:'destructive',onPress:remove}]);
  return <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={[styles.stack,{paddingBottom:24}]}>
    {adding ? <NewBin onSaved={saved} onClose={() => setAdding(false)} /> : <>
    <Button disabled={busy || sharing || store.isDeveloperMode} onPress={() => setAdding(true)}>Add a bin landmark</Button>
    <Button secondary disabled={sharing} onPress={() => setSettings(!settings)}>Community map connection</Button>
    {settings && <BinConnection onClose={() => setSettings(false)} onSaved={() => { cancel(); setCommunity([]); setSettings(false); setNotice('Connected. Search again to load community bins.'); }} />}
    <Label style={styles.caption}>{configured ? 'Community sharing connected. Purple pins are unverified submissions.' : 'Your saved bins stay on this phone until you connect a community server and choose Share.'} Blue pins are phone drafts; green pins are existing listings.</Label>
    {!!notice && <Panel><Label>{notice}</Label></Panel>}
    <Button disabled={busy} onPress={locate}>Use my location</Button>
    <TextInput accessibilityLabel="City and state or ZIP code" placeholder="City, state or ZIP" value={query} onChangeText={setQuery} style={styles.input} returnKeyType="search" onSubmitEditing={() => { if (!busy) findPlace(); }} />
    <Button secondary disabled={busy || query.trim().length < 3} onPress={findPlace}>Search this place</Button>
    <View style={[styles.row,{flexWrap:'wrap'}]}>{RADII.map(r => <Button key={r} secondary={r !== radius} disabled={busy} onPress={() => chooseRadius(r)}>{r / 1000} km</Button>)}</View>
    {busy && <><ActivityIndicator /><Button secondary onPress={() => { cancel(); setBusy(false); }}>Cancel search</Button></>}
    {!!error && <Label style={styles.error}>{error}</Label>}
    {denied && Platform.OS !== 'web' && <Button secondary onPress={() => Linking.openSettings().catch(() => setError('Open your phone settings to change location permission.'))}>Open phone settings</Button>}
    {area && <Button secondary disabled={busy} onPress={() => start((signal,epoch) => search(area,radius,signal,epoch))}>Refresh this area</Button>}
    {!!result?.notice && <Panel><Label>{result.notice}</Label></Panel>}
    {result?.stale && <Label>Cached listings from {new Date(result.fetchedAt).toLocaleString()}.</Label>}
    {area && <BinMap area={area} locations={locations} selected={selected} onSelect={setSelected} />}
    {location && <Panel style={styles.stack}><Label style={styles.subheading}>{location.name}</Label><Label>{location.kind}</Label>
      {photo && <Image source={{uri:photo}} accessibilityLabel={'Bin photo: ' + location.name} style={{height:220,width:'100%'}} resizeMode="contain" />}
      <Label>Listed materials: {location.materials.length ? location.materials.join(', ') : 'Unknown — check the signs.'}</Label>
      {location.notes && <Label>{location.notes}</Label>}{location.address && <Label>{location.address}</Label>}{location.hours && <Label>Hours: {location.hours}</Label>}
      <Label>{location.community ? 'Community · unverified. Public access was reported by the contributor; check signs and eligibility.' : location.onPhone ? 'Saved on this phone. Public access was confirmed by you.' : location.publicAccessListed ? 'Public access listed; check local eligibility.' : 'Access and eligibility unknown.'}{location.hasFee ? ' A fee is listed.' : ''}</Label>
      <Button onPress={() => open(directionsURL(location,Platform.OS))}>Directions</Button>
      {location.sourceURL && <Button secondary onPress={() => open(location.sourceURL)}>Source: {location.sourceName}</Button>}
      {location.onPhone && <><Label style={styles.caption}>Sharing publishes this photo, exact bin coordinates, name, materials, and notes to users of your community server.</Label>
        <Button disabled={!configured || sharing || store.isDeveloperMode} onPress={share}>{sharing ? 'Sharing…' : 'Share with community'}</Button></>}
      {(location.onPhone || (location.isMine && configured)) && <Button secondary disabled={sharing || store.isDeveloperMode} onPress={confirmRemove}>Remove landmark</Button>}
      {location.community && !location.isMine && location.localId && <Button secondary disabled={sharing || store.isDeveloperMode} onPress={async () => { try { store.assertReal(); await binRepository.remove(location.localId); setLocal(await binRepository.list()); } catch (e) { setError(e.message); } }}>Remove phone copy</Button>}
    </Panel>}
    {area && !locations.length && !busy && <Panel><Label>No recycling locations found here. Add a bin you find or try a wider radius.</Label></Panel>}
    {locations.map(l => <Button key={l.id} secondary={selected !== l.id} onPress={() => setSelected(l.id)}>{l.name + '\n' + (distance(area,l.coordinate) / 1000).toFixed(1) + ' km · ' + l.sourceName}</Button>)}
    <Label style={styles.caption}>Check materials before visiting. Adding a bin does not award leaves. City searches use OpenStreetMap.</Label>
    <Button secondary onPress={() => open('https://www.openstreetmap.org/copyright')}>© OpenStreetMap contributors</Button>
    <Button secondary onPress={() => open('https://www.houstontx.gov/solidwaste/recycling_map.html')}>City of Houston recycling data</Button>
    </>}
  </ScrollView>;
}
