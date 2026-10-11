import React, { useState } from 'react';
import { ActivityIndicator, ScrollView, Switch, TextInput, View } from 'react-native';
import { useGame } from './GameProvider';
import { ANIMALS, DECORATIONS, FOODS, HABITATS, foodCount, habitatActions, habitatID, placement } from './game';
import { connection, testConnection } from './verification';
import { Button, colors, Label, Panel, Sprite, styles } from './ui';
export { default as Developer } from './Developer';
export function Friends() {
  const {game} = useGame();
  const animals = ANIMALS.filter(a => a.habitat === habitatID(game)), count = habitatActions(game).length;
  const next = animals.find(a => count < a.required);
  return <View style={styles.stack}>
    <Label style={styles.subheading}>{animals.filter(a => count >= a.required).length} of 4 friends</Label>
    <View style={{flexDirection:'row',flexWrap:'wrap',gap:12}}>{animals.map(animal => {
      const unlocked = count >= animal.required;
      return <Panel key={animal.id} style={{flexGrow:1,flexBasis:'44%',alignItems:'center',gap:8,backgroundColor:unlocked ? colors.sage : colors.paper}}>
        <Sprite name={animal.id} size={80} style={{opacity:unlocked ? 1 : .3}} />
        <Label style={styles.subheading}>{animal.name}</Label><Label style={styles.caption}>{unlocked ? 'Collected' : animal.required + ' actions here'}</Label>
        <Label style={[styles.caption,{textAlign:'center'}]}>{animal.detail}</Label>
        {unlocked && <Label style={styles.caption}>{game.petMeals?.[animal.id] || 0} snacks enjoyed</Label>}
      </Panel>;
    })}</View>
    {next && <Label>{next.required - count} more actions in this habitat to meet {next.name}.</Label>}
  </View>;
}
export function Shop({ initial = 'decorations', onClose }) {
  const store = useGame(), game = store.game, habitat = habitatID(game);
  const [tab,setTab] = useState(initial), [busy,setBusy] = useState(false), [error,setError] = useState('');
  const act = async action => { setBusy(true); setError(''); try { await action(); } catch (e) { setError(e.message || 'Could not save. Please retry.'); } finally { setBusy(false); } };
  return <View style={styles.stack}>
    <View style={{flexDirection:'row',flexWrap:'wrap',gap:8}}>{['food','decorations','habitats'].map(t => <Button key={t} secondary={tab !== t} onPress={() => setTab(t)}>{t[0].toUpperCase() + t.slice(1)}</Button>)}</View>
    <View style={styles.row}><Sprite name="leaf" size={30} /><Label style={styles.subheading}>{game.points} leaves</Label></View>
    {!!error && <Label style={styles.error}>{error}</Label>}
    {tab === 'food' && <><Label>Buy a snack, choose Use, then tap a pet in your habitat.</Label>
      {FOODS.filter(f => f.habitats.includes(habitat)).map(food => <Panel key={food.id} style={styles.stack}>
        <View style={styles.row}><Sprite name={food.id} size={70} /><View style={{flex:1}}><Label style={styles.subheading}>{food.name}</Label><Label>{food.cost} leaves · {foodCount(game,food.id)} in bag</Label></View></View>
        <View style={styles.row}><Button disabled={busy || game.points < food.cost || foodCount(game,food.id) >= 99} onPress={() => act(() => store.buyFood(food.id))}>Buy</Button>
          <Button secondary disabled={busy || !foodCount(game,food.id)} onPress={() => { store.setSelectedFood(food.id); onClose?.(); }}>Use</Button></View>
      </Panel>)}</>}
    {tab === 'decorations' && <>{DECORATIONS.filter(d => d.habitat === habitat).map(item => {
      const owned = game.ownedDecorations.includes(item.id), locked = placement(game,item.id).locked;
      return <Panel key={item.id} style={styles.stack}>
        <View style={styles.row}><Sprite name={item.id} size={70} /><View style={{flex:1}}><Label style={styles.subheading}>{item.name}</Label>
          <Label>{owned ? locked ? 'Locked in place' : 'Drag to position in your habitat' : item.cost + ' leaves'}</Label>
          {!owned && game.points < item.cost && <Label style={styles.caption}>{item.cost - game.points} more to go</Label>}</View></View>
        {owned ? <Button secondary disabled={busy} onPress={() => act(() => store.lockDecoration(item.id,!locked))}>{locked ? 'Unlock' : 'Lock in place'}</Button> :
          <Button disabled={busy || game.points < item.cost} onPress={() => act(() => store.buy(item.id))}>Add {item.name}</Button>}
      </Panel>;
    })}<Button secondary disabled={busy} onPress={() => act(store.resetLayout)}>Reset this habitat’s positions & locks</Button></>}
    {tab === 'habitats' && HABITATS.map(h => <Panel key={h.id} style={styles.stack}><Label style={styles.subheading}>{h.name}</Label><Label>{h.detail}</Label>
      <Label style={styles.caption}>Your leaf wallet is shared. Each habitat has its own pollution and pet unlocks.</Label>
      <Button secondary={h.id === habitat} disabled={busy || h.id === habitat} onPress={() => act(async () => { await store.switchHabitat(h.id); onClose?.(); })}>{h.id === habitat ? 'You are here' : 'Visit · free'}</Button>
    </Panel>)}
  </View>;
}
export function Journal() {
  const {game} = useGame();
  return <View style={styles.stack}><Label style={styles.subheading}>{game.actions.length} actions across all habitats</Label>
    {!game.actions.length && <Panel><Label>Your first small step awaits. Tap Recycle to begin.</Label></Panel>}
    {[...game.actions].reverse().map(action => <Panel key={action.id} style={{gap:6}}>
      <View style={[styles.row,{justifyContent:'space-between'}]}><Label style={{fontWeight:'700',flex:1}}>{action.item}</Label><Label>+{action.reward}</Label></View>
      <Label style={styles.caption}>{new Date(action.date).toLocaleString()} · {HABITATS.find(h => h.id === (action.habitatID || 'grove'))?.name}</Label>
      <Label style={styles.caption}>{action.source === 'demo' ? 'Demo · automatically accepted' : action.source === 'preview' ? 'Developer preview' : action.source === 'ai' ? 'AI-reviewed · ' + action.material : 'Earlier self-reported action'}</Label>
      {action.tip && <Label style={styles.caption}>{action.tip}</Label>}
    </Panel>)}
  </View>;
}
export function Settings({ onDone }) {
  const { preferences, token, savePreferences, isPreview } = useGame();
  const [mode, setMode] = useState(preferences.mode);
  const [sound, setSound] = useState(preferences.sound);
  const [address, setAddress] = useState(preferences.url);
  const [accessToken, setAccessToken] = useState(token);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  return <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={[styles.stack, { paddingBottom: 24 }]}>
    <Label style={styles.heading}>Scan settings</Label>
    <View style={styles.row}><Button secondary={mode !== 'demo'} style={{ flex: 1 }} onPress={() => setMode('demo')}>Demo</Button>
      <Button secondary={mode !== 'ai'} disabled={isPreview} style={{ flex: 1 }} onPress={() => setMode('ai')}>AI review</Button></View>
    <Label>{mode === 'demo' ? 'Demo accepts three captures automatically and earns 20 leaves. No server is needed.' : 'Send three photos together for Gemini review. Approved actions earn 10–30 leaves; unclear reviews earn zero.'}</Label>
    <View style={[styles.row, { justifyContent: 'space-between' }]}><Label>Scan sounds</Label><Switch accessibilityLabel="Scan sounds" value={sound} onValueChange={setSound} trackColor={{ true: colors.forest }} /></View>
    {mode === 'ai' && <>
      <Label style={styles.subheading}>Review server</Label>
      <Label style={styles.caption}>Enter an HTTPS server or HTTPS tunnel to your PC. The Expo tunnel shares the app, not your review server.</Label>
      <TextInput accessibilityLabel="Review server address" style={styles.input} value={address} onChangeText={setAddress} placeholder="https://your-review-server.example" autoCapitalize="none" autoCorrect={false} keyboardType="url" />
      <Label style={styles.caption}>Server access token</Label>
      <TextInput accessibilityLabel="Server access token" style={styles.input} value={accessToken} onChangeText={setAccessToken} secureTextEntry autoCapitalize="none" autoCorrect={false} placeholder="ECOGOTCHI_ACCESS_TOKEN" />
      <Label style={styles.caption}>Your Gemini key stays on the server. The access token is saved securely on your phone.</Label>
    </>}
    {!!message && <Label accessibilityLiveRegion="polite">{message}</Label>}
    {busy && <ActivityIndicator color={colors.forest} />}
    <Button disabled={busy} onPress={async () => {
      setBusy(true); setMessage('');
      try {
        const config = mode === 'ai' ? connection(address, accessToken) : null;
        const status = config ? await testConnection(config) : null;
        await savePreferences({ mode, sound, url: config?.url || preferences.url }, config?.token || token);
        setMessage(status ? `Connected. ${status.reviewsRemaining} shared reviews remaining. This does not test Gemini’s key or quota.` : 'Demo settings saved.');
        if (!status) onDone();
      } catch (error) { setMessage(error.message); }
      finally { setBusy(false); }
    }}>{busy ? 'Saving…' : mode === 'ai' ? 'Save & test connection' : 'Save settings'}</Button>
    <Button secondary disabled={busy} onPress={onDone}>Done</Button>
  </ScrollView>;
}
