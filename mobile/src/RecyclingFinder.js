import React, { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Linking, Platform, ScrollView, TextInput, View } from 'react-native';
import { locate as deviceLocation } from './deviceLocation';
import BinMap from './BinMap';
import { areaFor, createLocationService, directionsURL, distance, RADII } from './locations';
import { Button, Label, Panel, styles } from './ui';
const service = createLocationService();
export default function RecyclingFinder() {
  const [query,setQuery] = useState(''), [radius,setRadius] = useState(5000), [area,setArea] = useState(null);
  const [result,setResult] = useState(null), [selected,setSelected] = useState(null), [busy,setBusy] = useState(false), [error,setError] = useState(''), [denied,setDenied] = useState(false);
  const request = useRef(null), generation = useRef(0);
  const cancel = () => { generation.current++; request.current?.abort(); request.current = null; };
  useEffect(() => () => cancel(),[]);
  const start = async work => {
    cancel(); const epoch = generation.current; request.current = new AbortController(); const signal = request.current.signal;
    setBusy(true); setError(''); setSelected(null);
    try { await work(signal,epoch); } catch (e) { if (generation.current === epoch && !signal.aborted) { setDenied(e.code === 'LOCATION_DENIED'); setError(e.message || 'Search failed. Check your connection.'); } }
    finally { if (generation.current === epoch) setBusy(false); }
  };
  const search = async (center,nextRadius,signal,epoch) => {
    const next = areaFor(center,nextRadius);
    if (signal.aborted || epoch !== generation.current) return;
    setArea(next); setResult(null);
    const found = await service.search(center,nextRadius,signal);
    if (!signal.aborted && epoch === generation.current) setResult(found);
  };
  const locate = () => start(async (signal,epoch) => {
    const center = await deviceLocation(signal);
    if (!signal.aborted) setDenied(false);
    await search(center,radius,signal,epoch);
  });
  const findPlace = () => start(async (signal,epoch) => { const center = await service.geocode(query,signal); await search(center,radius,signal,epoch); });
  const chooseRadius = next => { setRadius(next); if (area) start((signal,epoch) => search(area,next,signal,epoch)); };
  const location = result?.locations.find(l => l.id === selected);
  const open = url => Linking.openURL(url).catch(() => setError('Could not open that link. Check your maps app or browser.'));
  return <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={[styles.stack,{paddingBottom:24}]}>
    <Button disabled={busy} onPress={locate}>Use my location</Button>
    <Label style={styles.caption}>Location is requested only when you tap above. City searches use OpenStreetMap.</Label>
    <TextInput accessibilityLabel="City and state or ZIP code" placeholder="City, state or ZIP" value={query} onChangeText={setQuery}
      style={styles.input} returnKeyType="search" onSubmitEditing={() => { if (!busy) findPlace(); }} />
    <Button secondary disabled={busy || query.trim().length < 3} onPress={findPlace}>Search this place</Button>
    <View style={[styles.row,{flexWrap:'wrap'}]}>{RADII.map(r => <Button key={r} secondary={r !== radius} disabled={busy} onPress={() => chooseRadius(r)}>{r / 1000} km</Button>)}</View>
    {busy && <><ActivityIndicator /><Button secondary onPress={() => { cancel(); setBusy(false); }}>Cancel search</Button></>}
    {!!error && <Label style={styles.error}>{error}</Label>}
    {denied && Platform.OS !== 'web' && <Button secondary onPress={() => Linking.openSettings().catch(() => setError('Open your phone settings to change location permission.'))}>Open phone settings</Button>}
    {area && !busy && !!error && <Button secondary onPress={() => start((signal,epoch) => search(area,radius,signal,epoch))}>Try again</Button>}
    {!!result?.notice && <Panel><Label>{result.notice}</Label></Panel>}
    {result?.stale && <Label>Cached results from {new Date(result.fetchedAt).toLocaleString()}.</Label>}
    {result && <BinMap area={result.area} locations={result.locations} selected={selected} onSelect={setSelected} />}
    {location && <Panel style={styles.stack}><Label style={styles.subheading}>{location.name}</Label><Label>{location.kind}</Label>
      <Label>Listed materials: {location.materials.length ? location.materials.join(', ') : 'Unknown — check the location’s signs.'}</Label>
      {location.address && <Label>{location.address}</Label>}{location.hours && <Label>Hours: {location.hours}</Label>}
      <Label>{location.publicAccessListed ? 'Public access listed; check local eligibility.' : 'Access and eligibility unknown.'}{location.hasFee ? ' A fee is listed.' : ''}</Label>
      <Button onPress={() => open(directionsURL(location,Platform.OS))}>Directions</Button>
      <Button secondary onPress={() => open(location.sourceURL)}>Source: {location.sourceName}</Button>
    </Panel>}
    {result && !result.locations.length && <Panel style={styles.stack}><Label>No listed recycling locations in this area.</Label>
      {radius < 25000 && <Button secondary onPress={() => chooseRadius(radius === 5000 ? 10000 : 25000)}>Search farther</Button>}</Panel>}
    {result?.locations.map(l => <Button key={l.id} secondary={selected !== l.id} onPress={() => setSelected(l.id)}>{l.name + '\n' + (distance(result.area,l.coordinate) / 1000).toFixed(1) + ' km · ' + l.sourceName}</Button>)}
    <Label style={styles.caption}>Listings can change. Check accepted materials before visiting. Finding a bin does not award leaves.</Label>
    <Button secondary onPress={() => open('https://www.openstreetmap.org/copyright')}>© OpenStreetMap contributors</Button>
    <Button secondary onPress={() => open('https://www.houstontx.gov/solidwaste/recycling_map.html')}>City of Houston recycling data</Button>
  </ScrollView>;
}
