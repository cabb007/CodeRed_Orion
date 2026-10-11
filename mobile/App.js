import React, { useState } from 'react';
import { ActivityIndicator, Alert, Modal, Platform, Pressable, ScrollView, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { GameProvider, useGame } from './src/GameProvider';
import Habitat from './src/Habitat';
import Recycling from './src/Recycling';
import RecyclingFinder from './src/RecyclingFinder';
import { Developer, Friends, Journal, Shop } from './src/Panels';
import { FOODS, HABITATS, condition, foodCount, health } from './src/game';
import { Button, colors, Label, Panel, Sprite, styles } from './src/ui';
function EcoGotchi() {
  const store = useGame();
  const [panel,setPanel] = useState(null), [busy,setBusy] = useState(false), [sample,setSample] = useState(false), [rewardPreview,setRewardPreview] = useState(false);
  const open = name => { setSample(false); setRewardPreview(false); setPanel(name); };
  const close = () => { if (!busy) setPanel(null); };
  if (!store.loaded) return <SafeAreaView style={{flex:1,backgroundColor:colors.cream,padding:24,justifyContent:'center',gap:20}}>
    <Sprite name="pip" size={100} style={{alignSelf:'center'}} /><Label style={styles.heading}>EcoGotchi</Label>
    {store.error ? <><Label style={styles.error}>{store.error}</Label><Button onPress={store.retry}>Try loading again</Button>
      <Button secondary onPress={() => {
        const reset = () => store.reset();
        if (Platform.OS === 'web') { if (window.confirm('Reset all saved habitats? This clears your progress.')) reset(); }
        else Alert.alert('Reset saved habitats?','This clears your habitats, leaves, food, friends, and journal.',[{text:'Cancel',style:'cancel'},{text:'Reset',style:'destructive',onPress:reset}]);
      }}>Reset saved habitats</Button></> : <ActivityIndicator color={colors.forest} />}
  </SafeAreaView>;
  const game = store.game, selectedFood = FOODS.find(f => f.id === store.selectedFood);
  const title = {friends:'Friends',shop:'Shop',habitats:'Habitats',journal:'Journal',developer:'Developer preview',recycling:'Recycle',finder:'Find a bin'}[panel];
  const scan = mode => { setSample(mode === 'sample'); setRewardPreview(mode === 'reward'); setPanel('recycling'); };
  return <View style={{flex:1,backgroundColor:colors.cream}}>
    <StatusBar style="dark" /><Habitat game={game} enabled={!panel} />
    <SafeAreaView pointerEvents="box-none" style={{flex:1,paddingHorizontal:16,paddingBottom:12,gap:12}}>
      <View pointerEvents="box-none" style={[styles.row,{justifyContent:'space-between',flexWrap:'wrap',paddingTop:8,gap:6}]}>
        <Button secondary onPress={() => open('shop')} accessibilityLabel={game.points + ' leaves. Open shop'}>✦ {game.points}</Button>
        <Button secondary onPress={() => open('journal')}>Journal</Button>
        <Button secondary onPress={() => { store.beginPreview(); open('developer'); }}>{store.isPreview ? 'Dev: on' : 'Dev'}</Button>
      </View>
      <View style={{alignSelf:'center'}}><Button secondary onPress={() => open('finder')}>Find a bin</Button></View>
      <Pressable accessibilityRole="button" accessibilityLabel="Change habitat" onPress={() => open('habitats')} style={{alignSelf:'center'}}>
        <Panel style={{alignItems:'center',gap:4,backgroundColor:'#fffcebea',padding:10}}>
          <Label style={{fontWeight:'800',letterSpacing:1}}>{HABITATS.find(h => h.id === store.habitat).name.toUpperCase()} ▾</Label>
          <Label style={styles.caption}>{condition(game.litter).toUpperCase()} · {game.litter}/6 litter</Label>
          <View accessible accessibilityLabel={'Habitat health ' + health(game) + ' percent'} style={{flexDirection:'row',gap:3}}>
            {Array.from({length:10},(_,i) => <View key={i} style={{width:12,height:5,backgroundColor:i * 10 < health(game) ? colors.forest : colors.sage}} />)}
          </View>
        </Panel>
      </Pressable>
      {!!store.notice && <Panel><Label style={styles.caption}>{store.notice}</Label><Button secondary onPress={store.dismissNotice}>Dismiss</Button></Panel>}
      <View pointerEvents="none" style={{flex:1}} />
      {!!selectedFood && <Panel style={{padding:8}}><View style={[styles.row,{justifyContent:'space-between'}]}>
        <Sprite name={selectedFood.id} size={32} /><Label style={[styles.caption,{flex:1}]}>Tap a pet to feed {selectedFood.name}. {foodCount(game,selectedFood.id)} left.</Label>
        <Button secondary onPress={() => store.setSelectedFood(null)}>Done</Button>
      </View></Panel>}
      {store.isPreview && <Button secondary onPress={() => store.endPreview().catch(store.reportError)}>Exit preview · temporary changes</Button>}
      <View style={[styles.row,{alignItems:'flex-end',gap:8}]}>
        <View style={{flex:1}}><Button secondary onPress={() => open('friends')}>Friends</Button></View>
        <Button style={{minHeight:80}} onPress={() => open('recycling')}>{'RECYCLE\n' + (store.isPreview ? 'Preview' : store.preferences.mode === 'demo' ? '+20 leaves' : 'AI review')}</Button>
        <View style={{flex:1}}><Button secondary onPress={() => open('shop')}>Shop</Button></View>
      </View>
    </SafeAreaView>
    <Modal visible={!!panel} animationType="slide" presentationStyle="fullScreen" onRequestClose={close}>
      <SafeAreaView style={{flex:1,backgroundColor:colors.cream}}>
        <View style={[styles.row,{padding:20,justifyContent:'space-between'}]}><Label style={[styles.heading,{flex:1}]}>{title}</Label>
          <Button secondary disabled={busy} accessibilityLabel={'Close ' + title} onPress={close}>✕</Button></View>
        <View style={{flex:1,paddingHorizontal:20}}>
          {panel === 'recycling' ? <Recycling sample={sample} rewardPreview={rewardPreview} onClose={close} onBusy={setBusy} /> :
            panel === 'finder' ? <RecyclingFinder /> : <ScrollView contentContainerStyle={{paddingBottom:24}}>
              {panel === 'friends' && <Friends />}{(panel === 'shop' || panel === 'habitats') && <Shop initial={panel === 'habitats' ? 'habitats' : 'decorations'} onClose={close} />}
              {panel === 'journal' && <Journal />}
              {panel === 'developer' && <Developer onSample={() => scan('sample')} onCamera={() => scan('camera')} onReward={() => scan('reward')} />}
            </ScrollView>}
        </View>
      </SafeAreaView>
    </Modal>
  </View>;
}
export default function App() { return <SafeAreaProvider><GameProvider><EcoGotchi /></GameProvider></SafeAreaProvider>; }
