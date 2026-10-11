import React, { useState } from 'react';
import { ActivityIndicator, Alert, Modal, Platform, ScrollView, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { GameProvider, useGame } from './src/GameProvider';
import Habitat from './src/Habitat';
import Recycling from './src/Recycling';
import { Developer, Friends, Journal, Shop } from './src/Panels';
import { condition, health } from './src/game';
import { Button, colors, Label, Panel, Sprite, styles } from './src/ui';

function EcoGotchi() {
  const store = useGame();
  const [panel, setPanel] = useState(null);
  const [busy, setBusy] = useState(false);
  const [sample, setSample] = useState(false);
  const open = name => { setSample(false); setPanel(name); };
  const close = () => { if (!busy) setPanel(null); };
  if (!store.loaded) return <SafeAreaView style={{ flex: 1, backgroundColor: colors.cream, padding: 24, justifyContent: 'center', gap: 20 }}>
    <Sprite name="pip" size={100} style={{ alignSelf: 'center' }} /><Label style={styles.heading}>EcoGotchi</Label>
    {store.error ? <><Label style={styles.error}>{store.error}</Label><Button onPress={store.retry}>Try loading again</Button>
      <Button secondary onPress={() => {
        const reset = () => store.reset();
        if (Platform.OS === 'web') { if (window.confirm('Reset the saved grove? This clears your progress.')) reset(); }
        else Alert.alert('Reset saved grove?', 'This clears your habitat, leaves, friends, and journal.', [{ text: 'Cancel', style: 'cancel' }, { text: 'Reset', style: 'destructive', onPress: reset }]);
      }}>Reset saved grove</Button></> : <ActivityIndicator color={colors.forest} />}
  </SafeAreaView>;
  const game = store.game;
  const title = { friends: 'Friends', shop: 'Decorate', journal: 'Journal', developer: 'Developer preview', recycling: 'Recycle' }[panel];
  return <View style={{ flex: 1, backgroundColor: colors.cream }}>
    <StatusBar style="dark" />
    <Habitat game={game} />
    <SafeAreaView style={{ flex: 1, paddingHorizontal: 20, paddingBottom: 12, gap: 16 }}>
      <View style={[styles.row, { justifyContent: 'space-between', flexWrap: 'wrap', paddingTop: 8 }]}>
        <Button secondary onPress={() => open('shop')} accessibilityLabel={`${game.points} leaves. Open decorations`}>✦ {game.points}</Button>
        <View style={{ flexDirection: 'row', gap: 8 }}><Button secondary onPress={() => open('journal')}>Journal</Button>
          <Button secondary onPress={() => { store.beginPreview(); open('developer'); }}>{store.isPreview ? 'Dev: on' : 'Dev'}</Button></View>
      </View>
      <Panel style={{ alignSelf: 'center', alignItems: 'center', gap: 6, backgroundColor: '#fffcebea' }}>
        <Label style={{ fontWeight: '800', letterSpacing: 2 }}>WILLOW GROVE</Label>
        <Label style={styles.caption}>{condition(game.litter).toUpperCase()} · {game.litter}/6 litter</Label>
        <View accessible accessibilityLabel={`Habitat health ${health(game)} percent`} style={{ flexDirection: 'row', gap: 3 }}>
          {Array.from({ length: 10 }, (_, i) => <View key={i} style={{ width: 12, height: 5, backgroundColor: i * 10 < health(game) ? colors.forest : colors.sage }} />)}
        </View>
      </Panel>
      {!!store.notice && <Panel><Label style={styles.caption}>{store.notice}</Label><Button secondary onPress={store.dismissNotice}>Dismiss</Button></Panel>}
      <View style={{ flex: 1 }} />
      {store.isPreview && <Button secondary onPress={() => store.endPreview().catch(() => open('developer'))}>Exit preview · temporary changes</Button>}
      <View style={[styles.row, { alignItems: 'flex-end' }]}>
        <View style={{ flex: 1 }}><Button secondary onPress={() => open('friends')}>Friends</Button></View>
        <Button style={{ minHeight: 88 }} onPress={() => open('recycling')}>{`RECYCLE\n${store.isPreview ? 'Preview' : store.preferences.mode === 'demo' ? '+20 leaves' : 'AI review'}`}</Button>
        <View style={{ flex: 1 }}><Button secondary onPress={() => open('shop')}>Decorate</Button></View>
      </View>
    </SafeAreaView>
    <Modal visible={!!panel} animationType="slide" presentationStyle="fullScreen" onRequestClose={close}>
      <SafeAreaView style={{ flex: 1, backgroundColor: colors.cream }}>
        <View style={[styles.row, { padding: 20, justifyContent: 'space-between' }]}><Label style={[styles.heading, { flex: 1 }]}>{title}</Label><Button secondary disabled={busy} accessibilityLabel={`Close ${title}`} onPress={close}>✕</Button></View>
        <View style={{ flex: 1, paddingHorizontal: 20 }}>
          {panel === 'recycling' ? <Recycling sample={sample} onClose={close} onBusy={setBusy} /> : <ScrollView contentContainerStyle={{ paddingBottom: 24 }}>
            {panel === 'friends' && <Friends />}{panel === 'shop' && <Shop />}{panel === 'journal' && <Journal />}
            {panel === 'developer' && <Developer onSample={() => { setSample(true); setPanel('recycling'); }} />}
          </ScrollView>}
        </View>
      </SafeAreaView>
    </Modal>
  </View>;
}
export default function App() { return <SafeAreaProvider><GameProvider><EcoGotchi /></GameProvider></SafeAreaProvider>; }
