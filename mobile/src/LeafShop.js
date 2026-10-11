import React, { useState } from 'react';
import { View } from 'react-native';
import { Button, Label, Panel, Sprite, styles } from './ui';

// Display quantities only. Pricing and checkout will be added when purchases launch.
export const LEAF_PACKS = [
  {id:'starter',name:'Little Sprout',leaves:100},
  {id:'garden',name:'Growing Garden',leaves:500},
  {id:'forest',name:'Forest of Leaves',leaves:1200},
];
export default function LeafShop() {
  const [selected,setSelected] = useState(null);
  return <View style={styles.stack}>
    <Label style={styles.subheading}>Buy Leaves</Label>
    <Label style={styles.caption}>Leaves for cosmetics, snacks, and habitat extras.</Label>
    {LEAF_PACKS.map(pack => <Panel key={pack.id} style={styles.stack}>
      <View style={styles.row}><Sprite name="leaf" size={48} /><View style={{flex:1}}>
        <Label style={styles.subheading}>{pack.name}</Label><Label>{pack.leaves.toLocaleString()} leaves</Label>
      </View></View>
      <Label style={styles.caption}>Price available at launch</Label>
      <Button accessibilityLabel={'Buy ' + pack.leaves + ' leaves. Coming soon.'} onPress={() => setSelected(pack.id)}>Buy {pack.leaves.toLocaleString()} leaves</Button>
      {selected === pack.id && <View style={styles.stack}>
        <Label accessibilityLiveRegion="polite">Buying {pack.leaves.toLocaleString()} leaves is coming soon. Checkout is not available yet, and no money has been charged or leaves added.</Label>
        <Button secondary onPress={() => setSelected(null)}>Got it</Button>
      </View>}
    </Panel>)}
    <View style={{gap:6,paddingHorizontal:4}}>
      <Label style={styles.caption}>When purchases launch, 80% of each leaf purchase will support preservation, conservation, and wildlife reserve organizations.</Label>
      <Label style={styles.caption}>Purchases and donations are coming soon. No payment is collected here.</Label>
    </View>
  </View>;
}
