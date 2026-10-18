import React, { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { PanResponder, Pressable, View } from 'react-native';
import { useGame } from './GameProvider';
import { bounded, boundsFor } from './motion';
import { Button, colors, Label, Sprite } from './ui';
export default function InteractiveDecoration({ item, area, home, size, placement, selected, onSelect, active, reduceMotion, labels }) {
  const store = useGame();
  const bounds = boundsFor(area,size);
  const original = bounded(placement.x === undefined ? home : {x:area.x + area.width * placement.x,y:area.y + area.height * placement.y},bounds);
  const [draft,setDraft] = useState(null);
  const origin = useRef(null), current = useRef(null);
  const lock = () => store.lockDecoration(item.id,!placement.locked).catch(store.reportError);
  useLayoutEffect(() => { current.current = {original,bounds,area,active,placement,onSelect,store}; });
  useEffect(() => { const frame = requestAnimationFrame(() => { origin.current = null; setDraft(null); }); return () => cancelAnimationFrame(frame); },[active,placement,size,area.width,area.height]);
  // PanResponder stores these callbacks; refs are read only during dispatched gestures.
  // eslint-disable-next-line react-hooks/refs
  const gesture = useMemo(() => PanResponder.create({
    onMoveShouldSetPanResponder:(_,g) => current.current.active && !current.current.placement.locked && Math.abs(g.dx) + Math.abs(g.dy) > 4,
    onPanResponderGrant:() => { origin.current = current.current.original; current.current.onSelect(); },
    onPanResponderMove:(_,g) => { if (origin.current) setDraft(bounded({x:origin.current.x + g.dx,y:origin.current.y + g.dy},current.current.bounds)); },
    onPanResponderRelease:(_,g) => {
      if (!origin.current) return;
      const c = current.current, p = bounded({x:origin.current.x + g.dx,y:origin.current.y + g.dy},c.bounds);
      origin.current = null;
      c.store.moveDecoration(item.id,(p.x - c.area.x) / c.area.width,(p.y - c.area.y) / c.area.height)
        .catch(c.store.reportError).finally(() => setDraft(null));
    },
    onPanResponderTerminate:() => { origin.current = null; setDraft(null); },
  }),[]);
  const p = draft || original;
  return <View style={{position:'absolute',left:p.x - size / 2,top:p.y - size / 2,width:size,height:size,zIndex:draft ? 200 : selected ? 90 : 2}}>
    <Pressable {...gesture.panHandlers} disabled={!active} onPress={onSelect} accessibilityRole="button" accessibilityLabel={item.name}
      accessibilityValue={{text:placement.locked ? 'Locked in place' : 'Movable'}} accessibilityHint="Drag to position. Tap to show lock controls."
      accessibilityActions={[{name:'activate',label:'Select'},{name:'lock',label:placement.locked ? 'Unlock' : 'Lock'}]}
      onAccessibilityAction={e => e.nativeEvent.actionName === 'lock' ? lock() : onSelect()}
      style={{borderWidth:selected ? 2 : 0,borderColor:colors.forest,borderStyle:'dashed',minWidth:44,minHeight:44,transform:[{scale:draft && !reduceMotion ? 1.08 : 1}]}}>
      <Sprite name={item.id} size={size} />
    </Pressable>
    {selected && !draft && <View style={{position:'absolute',bottom:size + 4,alignSelf:'center'}}><Button secondary onPress={lock}>{placement.locked ? 'Unlock' : 'Lock'}</Button></View>}
    {(labels || selected) && <Label pointerEvents="none" style={{fontSize:9,lineHeight:14,textAlign:'center',backgroundColor:colors.paper}}>{placement.locked ? 'Locked' : item.name}</Label>}
  </View>;
}
