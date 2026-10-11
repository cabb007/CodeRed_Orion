import React, { useState } from 'react';
import { Switch, View } from 'react-native';
import { useGame, uuid } from './GameProvider';
import { ANIMALS, DECORATIONS, FOODS, HABITATS, advance, habitatActions, habitatID, newGame, previewActionCount, developerDefaults } from './game';
import { Button, colors, Label, Panel, styles } from './ui';
function Toggle({ label, value, onChange }) { return <View style={[styles.row,{justifyContent:'space-between'}]}><Label style={{flex:1}}>{label}</Label><Switch accessibilityLabel={label} value={value} onValueChange={onChange} /></View>; }
function Counter({label,value,onChange,min = 0,max = 100,step = 1}) {
  return <View style={[styles.row,{flexWrap:'wrap'}]}><Label style={{flex:1}}>{label}: {Number(value.toFixed(1))}</Label>
    <Button secondary disabled={value <= min} accessibilityLabel={'Decrease ' + label} onPress={() => onChange(Math.max(min,value - step))}>−</Button>
    <Button secondary disabled={value >= max} accessibilityLabel={'Increase ' + label} onPress={() => onChange(Math.min(max,value + step))}>+</Button></View>;
}
export default function Developer({ onSample, onCamera, onReward }) {
  const store = useGame(), game = store.game, d = store.developer, habitat = habitatID(game);
  const [category,setCategory] = useState('Habitat'), [error,setError] = useState('');
  const run = async work => { setError(''); try { await work(); } catch (e) { setError(e.message); } };
  const edit = transform => run(() => store.editDeveloper(transform));
  const configure = store.configureDeveloper;
  const timeSkip = hours => edit(g => advance({...g,lastPollution:Date.now() - hours * 3600000},Date.now(),d.interval));
  const modeControl = <Panel style={[styles.stack,{backgroundColor:colors.gold}]}>
    <View style={[styles.row,{justifyContent:'space-between'}]}>
      <Label style={styles.subheading}>Dev Mode {store.isDeveloperMode ? 'on' : 'off'}</Label>
      <Switch accessibilityLabel="Dev Mode" value={store.isDeveloperMode} disabled={store.modeChanging}
        onValueChange={enabled => run(() => store.setDeveloperMode(enabled))} />
    </View>
    <Label>Test changes in a temporary copy of your habitat. Turning this off discards the changes and restores your real progress and settings.</Label>
    <Label style={styles.caption}>Real purchases and saved bin changes are unavailable here. Restarting the app returns to real mode.</Label>
    {store.modeChanging && <Label accessibilityLiveRegion="polite">Switching mode…</Label>}
  </Panel>;
  if (!store.isDeveloperMode || store.modeChanging) return <View style={styles.stack}>{modeControl}
    {!!error && <Label style={styles.error}>{error}</Label>}
    {!store.modeChanging && <Label>Your real habitat is active. Turn on Dev Mode to access the test controls.</Label>}
  </View>;
  return <View style={styles.stack}>
    {modeControl}
    <View style={{flexDirection:'row',flexWrap:'wrap',gap:8}}>{['Habitat','Friends','Rewards','Tools'].map(c => <Button key={c} secondary={category !== c} onPress={() => setCategory(c)}>{c}</Button>)}</View>
    {!!error && <Label style={styles.error}>{error}</Label>}
    {category === 'Habitat' && <>
      {HABITATS.map(h => <Button key={h.id} secondary={h.id !== habitat} onPress={() => run(() => store.switchHabitat(h.id))}>{h.name}</Button>)}
      <View style={{flexDirection:'row',flexWrap:'wrap',gap:8}}>{[0,2,4,6].map(litter => <Button key={litter} secondary onPress={() => edit(g => ({...g,litter,lastPollution:Date.now()}))}>{['Thriving','','Littered','','Tarnished','','Polluted'][litter]}</Button>)}</View>
      <Counter label="Trash" value={game.litter} max={6} onChange={litter => edit(g => ({...g,litter,lastPollution:Date.now()}))} />
      <Toggle label="Pause automatic trash" value={d.pausePollution} onChange={pausePollution => configure({pausePollution})} />
      <Label>Drop interval</Label><View style={{flexDirection:'row',flexWrap:'wrap',gap:8}}>{[5000,30000,60000,14400000].map(interval => <Button key={interval} secondary={d.interval !== interval}
        onPress={() => { configure({interval}); edit(g => ({...g,lastPollution:Date.now()})); }}>{interval === 14400000 ? '4 hours' : interval / 1000 + ' sec'}</Button>)}</View>
      <Button secondary onPress={() => timeSkip(4)}>Skip 4 hours</Button><Button secondary onPress={() => timeSkip(24)}>Skip 24 hours</Button>
    </>}
    {category === 'Friends' && <>
      <Counter label="Actions here" value={habitatActions(game).length} max={30} onChange={count => edit(g => previewActionCount(g,count))} />
      <Button secondary onPress={() => edit(g => previewActionCount(g,6))}>Unlock all local friends</Button>
      <Toggle label="Keep animals out when polluted" value={d.ignoreRetreat} onChange={ignoreRetreat => configure({ignoreRetreat})} />
      {ANIMALS.filter(a => a.habitat === habitat).map(a => <Toggle key={a.id} label={'Show ' + a.name} value={!d.hiddenAnimals.includes(a.id)}
        onChange={visible => configure({hiddenAnimals:visible ? d.hiddenAnimals.filter(id => id !== a.id) : [...d.hiddenAnimals,a.id]})} />)}
    </>}
    {category === 'Rewards' && <>
      <Counter label="Leaves" value={game.points} max={10000} step={20} onChange={points => edit(g => ({...g,points}))} />
      <Button secondary onPress={() => edit(g => ({...g,points:0}))}>Set leaves to zero</Button><Button secondary onPress={() => edit(g => ({...g,points:Math.min(10000,g.points + 200)}))}>Add 200 leaves</Button>
      <Counter label="Leaves per action" value={d.actionReward} step={5} onChange={actionReward => configure({actionReward})} />
      <Counter label="Trash cleared per action" value={d.cleanup} max={6} onChange={cleanup => configure({cleanup})} />
      <Button onPress={() => run(() => store.recordDemo(uuid()))}>Simulate completed recycling</Button>
      {DECORATIONS.filter(item => item.habitat === habitat).map(item => <Toggle key={item.id} label={item.name} value={game.ownedDecorations.includes(item.id)}
        onChange={owned => edit(g => ({...g,ownedDecorations:owned ? [...new Set([...g.ownedDecorations,item.id])] : g.ownedDecorations.filter(id => id !== item.id)}))} />)}
      <Button secondary onPress={() => edit(g => ({...g,foodInventory:Object.fromEntries(FOODS.map(f => [f.id,5]))}))}>Stock five of every food</Button>
      {FOODS.map(f => <Counter key={f.id} label={f.name} value={game.foodInventory?.[f.id] || 0} max={99} onChange={n => edit(g => ({...g,foodInventory:{...g.foodInventory,[f.id]:n}}))} />)}
    </>}
    {category === 'Tools' && <>
      <Button onPress={onCamera}>Test camera capture</Button><Button secondary onPress={onSample}>Guided capture demo</Button><Button secondary onPress={onReward}>Preview reward screen</Button>
      {[['animateAnimals','Pets roam on their own'],['animateHabitat','Habitat animations'],['showAtmosphere','Show habitat effects'],['showLabels','Element labels'],['showGrid','Placement grid']].map(([key,label]) =>
        <Toggle key={key} label={label} value={d[key]} onChange={v => configure({[key]:v})} />)}
      <Counter label="Sprite size" value={d.spriteScale} min={.5} max={1.8} step={.1} onChange={spriteScale => configure({spriteScale})} />
      <Label style={styles.caption}>Reduce Motion takes priority. Developer scans never call Gemini.</Label>
    </>}
    <Button secondary onPress={() => edit(g => ({...previewActionCount(g,6),litter:0,points:200,foodInventory:Object.fromEntries(FOODS.map(f => [f.id,5]))}))}>Thriving demo · friends + 200 leaves</Button>
    <Button secondary onPress={() => { configure(developerDefaults()); store.setSelectedFood(null); edit(() => newGame()); }}>Reset this developer habitat</Button>
    <Button onPress={() => run(() => store.setDeveloperMode(false))}>Turn off Dev Mode</Button>
  </View>;
}
