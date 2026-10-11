import React, { useState } from 'react';
import { ActivityIndicator, ScrollView, Switch, TextInput, View } from 'react-native';
import { useGame } from './GameProvider';
import { ANIMALS, DECORATIONS, newGame } from './game';
import { connection, testConnection } from './verification';
import { Button, colors, Label, Panel, Sprite, styles } from './ui';

export function Friends() {
  const { game } = useGame();
  const next = ANIMALS.find(a => game.actions.length < a.required);
  return <View style={styles.stack}>
    <Label style={styles.subheading}>{ANIMALS.filter(a => game.actions.length >= a.required).length} of 4 friends</Label>
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 12 }}>
      {ANIMALS.map(animal => {
        const unlocked = game.actions.length >= animal.required;
        return <Panel key={animal.id} style={{ flexGrow: 1, flexBasis: '44%', alignItems: 'center', gap: 8, backgroundColor: unlocked ? colors.sage : colors.paper }}>
          <Sprite name={animal.id} size={80} style={{ opacity: unlocked ? 1 : 0.3 }} />
          <Label style={styles.subheading}>{animal.name}</Label>
          <Label style={styles.caption}>{unlocked ? 'Collected' : `${animal.required} actions`}</Label>
          <Label style={[styles.caption, { textAlign: 'center' }]}>{animal.detail}</Label>
        </Panel>;
      })}
    </View>
    {next && <Label>{next.required - game.actions.length} more actions to meet {next.name}.</Label>}
  </View>;
}
export function Shop() {
  const { game, buy } = useGame();
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  return <View style={styles.stack}>
    <View style={styles.row}><Sprite name="leaf" size={30} /><Label style={styles.subheading}>{game.points} leaves</Label></View>
    {DECORATIONS.map(item => {
      const owned = game.ownedDecorations.includes(item.id);
      return <Panel key={item.id} style={styles.stack}>
        <View style={styles.row}><Sprite name={item.id} size={70} /><View style={{ flex: 1 }}>
          <Label style={styles.subheading}>{item.name}</Label><Label>{owned ? 'In your habitat' : `${item.cost} leaves`}</Label>
          {!owned && game.points < item.cost && <Label style={styles.caption}>{item.cost - game.points} more to go</Label>}
        </View></View>
        <Button secondary={owned} disabled={owned || game.points < item.cost || busy} onPress={async () => {
          setBusy(true); setError('');
          try { await buy(item.id); } catch { setError('The purchase could not be saved. No leaves were spent. Try again.'); }
          finally { setBusy(false); }
        }}>{owned ? 'Owned' : `Add ${item.name}`}</Button>
      </Panel>;
    })}
    {!!error && <Label style={styles.error}>{error}</Label>}
    <Label style={styles.caption}>Decorations appear in your grove as soon as you add them.</Label>
  </View>;
}
export function Journal() {
  const { game } = useGame();
  return <View style={styles.stack}>
    <Label style={styles.subheading}>{game.actions.length} actions logged</Label>
    {!game.actions.length && <Panel><Label>Your first small step awaits. Tap Recycle to begin.</Label></Panel>}
    {[...game.actions].reverse().map(action => <Panel key={action.id} style={{ gap: 6 }}>
      <View style={[styles.row, { justifyContent: 'space-between' }]}><Label style={{ fontWeight: '700', flex: 1 }}>{action.item}</Label><Label>+{action.reward}</Label></View>
      <Label style={styles.caption}>{new Date(action.date).toLocaleString()}</Label>
      <Label style={styles.caption}>{action.source === 'demo' ? 'Demo · automatically accepted' : action.source === 'preview' ? 'Developer preview' : `AI-reviewed · ${action.material}`}</Label>
      {action.tip && <Label style={styles.caption}>{action.tip}</Label>}
    </Panel>)}
  </View>;
}
export function Developer({ onSample }) {
  const { game, editPreview, endPreview } = useGame();
  const [error, setError] = useState('');
  return <View style={styles.stack}>
    <Panel style={{ backgroundColor: colors.gold }}><Label>Preview changes are temporary. Exit preview to return to your saved grove.</Label></Panel>
    <Label style={styles.subheading}>Habitat</Label>
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{[0, 2, 4, 6].map(litter => <Button key={litter} secondary onPress={() => editPreview(g => ({ ...g, litter }))}>{litter} litter</Button>)}</View>
    <Button secondary onPress={() => editPreview(g => ({ ...g, points: 200 }))}>Set 200 leaves</Button>
    <Button secondary onPress={() => editPreview(g => ({ ...g, actions: Array.from({ length: 6 }, (_, i) => ({ id: `preview-${i}`, item: '[Preview] Recycling', date: new Date().toISOString(), reward: 20, source: 'preview' })) }))}>Meet all friends</Button>
    <Button secondary onPress={() => editPreview(g => ({ ...g, ownedDecorations: DECORATIONS.map(d => d.id) }))}>Show all decorations</Button>
    <Button secondary onPress={onSample}>Guided capture demo</Button>
    <Button secondary onPress={() => editPreview(() => newGame())}>Reset preview</Button>
    <Label style={styles.caption}>{game.points} preview leaves · {game.actions.length} preview actions</Label>
    {!!error && <Label style={styles.error}>{error}</Label>}
    <Button onPress={() => endPreview().catch(() => setError('Could not refresh the saved grove. Try again.'))}>Exit preview</Button>
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
      <Label style={styles.caption}>Your Gemini key stays on the server. The access token is saved securely on your iPhone.</Label>
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
