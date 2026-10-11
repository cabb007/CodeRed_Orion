import React, { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { AccessibilityInfo, PanResponder, View } from 'react-native';
import * as Haptics from 'expo-haptics';
import { useGame } from './GameProvider';
import { bounded, boundsFor, clamp, drop, settle, stepBody, walk } from './motion';
import { Label, Sprite, colors } from './ui';
import { DROP_SOUNDS, MOODS } from './animalExpressions';
export default function InteractivePet({ animal, home, area, size, active, reduceMotion, roam, labels, world, habitatCondition }) {
  const store = useGame();
  const bounds = boundsFor(area,size * 1.2,home.y);
  const body = useRef(settle(home,bounds));
  const collide = n => world.move(animal.id,n,bounds,size);
  const dragging = useRef(null), target = useRef(null), nextWalk = useRef(0), timer = useRef(null), mounted = useRef(true), feeding = useRef(false);
  const [pose,setPose] = useState(() => settle(home,bounds));
  const [reaction,setReaction] = useState(null);
  const [lifted,setLifted] = useState(false);
  const [tilt,setTilt] = useState(0);
  const facing = useRef(false), phase = useRef(0);
  const current = useRef(null);
  const show = message => {
    clearTimeout(timer.current); target.current = null; nextWalk.current = Date.now() + 2200;
    setReaction(message); timer.current = setTimeout(() => { if (mounted.current) setReaction(null); },1600);
  };
  const pet = async (feed = true) => {
    if (!active || feeding.current) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Soft).catch(() => {});
    if (feed && store.selectedFood) {
      const food = store.selectedFood; feeding.current = true;
      try {
        const result = await store.feed(animal.id,food);
        if (mounted.current && result.applied) { show({text:'Yum! Thank you!',food}); AccessibilityInfo.announceForAccessibility(animal.name + ' enjoyed a snack.'); }
      } catch (error) { store.reportError(error); }
      finally { feeding.current = false; }
    } else { show({text:'So happy!'}); AccessibilityInfo.announceForAccessibility(animal.name + ' is happy!'); }
  };
  const returnHome = () => { dragging.current = null; target.current = null; body.current = collide(settle(home,bounds)); setPose(body.current); setLifted(false); setTilt(0); };
  useLayoutEffect(() => { current.current = {bounds,active,reduceMotion,pet,returnHome,collide}; });
  useLayoutEffect(() => {
    world.listen(animal.id,next => { body.current = next; setPose(next); target.current = null; });
    body.current = collide(body.current);
    // Resolve initial placement before painting the habitat.
    setPose(body.current);
    return () => world.remove(animal.id);
  },[world,animal.id,size,bounds.left,bounds.right,bounds.top,bounds.bottom]);
  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; clearTimeout(timer.current); };
  },[]);
  useEffect(() => { const frame = requestAnimationFrame(() => { dragging.current = null; target.current = null; body.current = collide(settle(body.current,bounds)); setPose(body.current); setLifted(false); setTilt(0); }); return () => cancelAnimationFrame(frame); },[area.x,area.y,area.width,area.height,size,home.y,active,reduceMotion,world]);
  useEffect(() => {
    if (!active || reduceMotion) return;
    let last = Date.now();
    const loop = setInterval(() => {
      const now = Date.now(), dt = Math.min(.1,(now - last) / 1000); last = now;
      if (dragging.current) return;
      let n = body.current;
      if (!n.grounded) n = stepBody(n,dt,current.current.bounds,animal.habitat === 'ocean' ? 220 : 1450);
      else if (roam && !reaction) {
        if (target.current === null && now >= nextWalk.current) target.current = bounds.left + Math.random() * (bounds.right - bounds.left);
        if (target.current !== null) {
          facing.current = target.current < n.x;
          const next = walk(n,target.current,animal.id === 'maple' ? 27 : 21,dt,bounds);
          phase.current += Math.abs(next.x - n.x) * .32; n = next;
          if (Math.abs(target.current - n.x) < .5) { target.current = null; nextWalk.current = now + 1200 + Math.random() * 1800; }
        }
      } else target.current = null;
      const moved = collide(n);
      if (Math.abs(moved.x - n.x) > .1 || Math.abs(moved.y - n.y) > .1) { target.current = null; nextWalk.current = now + 700; }
      n = moved; body.current = n; setPose({...n,facing:facing.current,phase:phase.current,walking:target.current !== null});
    },33);
    return () => clearInterval(loop);
  },[active,reduceMotion,roam,reaction,bounds.left,bounds.right,bounds.top,bounds.bottom,world,size,animal.id]);
  // PanResponder stores these callbacks; refs are read only during dispatched gestures.
  // eslint-disable-next-line react-hooks/refs
  const gesture = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder:() => current.current.active,
    onPanResponderGrant:() => { dragging.current = {...body.current}; target.current = null; },
    onPanResponderMove:(_,g) => {
      if (!dragging.current) return;
      if (Math.abs(g.dx) + Math.abs(g.dy) < 4) return;
      setLifted(true); setTilt(current.current.reduceMotion ? 0 : clamp(g.vx * 25,-28,28));
      body.current = current.current.collide({...body.current,...bounded({x:dragging.current.x + g.dx,y:dragging.current.y + g.dy},current.current.bounds)});
      setPose(body.current);
    },
    onPanResponderRelease:(_,g) => {
      dragging.current = null; setLifted(false); setTilt(0);
      if (Math.abs(g.dx) + Math.abs(g.dy) < 4) { void current.current.pet(); return; }
      body.current = current.current.reduceMotion ? settle(body.current,current.current.bounds) :
        drop(body.current,{x:g.vx * 1000,y:g.vy * 1000},current.current.bounds);
      body.current = current.current.collide(body.current);
      setPose(body.current); show({text:DROP_SOUNDS[animal.id] || 'Wheee!'}); AccessibilityInfo.announceForAccessibility(animal.name + ': ' + (DROP_SOUNDS[animal.id] || 'Wheee!')); Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Soft).catch(() => {});
    },
    onPanResponderTerminate:() => current.current.returnHome(),
  }),[]);
  const bob = reduceMotion || lifted || !active ? 0 : reaction ? -8 : roam && pose.walking ? (animal.habitat === 'ocean' ? Math.sin((pose.phase || 0) * .4) * 5 : -Math.abs(Math.sin(pose.phase || 0)) * 3) : 0;
  return <View {...gesture.panHandlers} accessible accessibilityRole="button" accessibilityLabel={animal.name + ', ' + (reaction ? 'happy' : MOODS[habitatCondition] || 'happy')}
    accessibilityHint={store.selectedFood ? 'Double-tap to feed. Drag to pick up.' : 'Double-tap to pet. Drag to pick up.'}
    accessibilityActions={[{name:'activate',label:'Pet or feed'},{name:'pet',label:'Pet'},{name:'home',label:'Return to starting spot'}]}
    onAccessibilityAction={e => e.nativeEvent.actionName === 'home' ? returnHome() : pet(e.nativeEvent.actionName !== 'pet')}
    style={{position:'absolute',left:pose.x - size / 2,top:pose.y - size / 2,width:size,height:size,minWidth:44,minHeight:44,zIndex:lifted ? 100 : 10}}>
    {animal.habitat !== 'ocean' && <View pointerEvents="none" style={{position:'absolute',bottom:-3,left:size * .17,width:size * .66,height:size * .12,borderRadius:50,backgroundColor:'#24403333'}} />}
    <Sprite name={animal.id} expression={reaction ? 'Thriving' : habitatCondition} size={size} style={{transform:[{translateY:bob},{rotate:tilt + 'deg'},{scaleX:pose.facing ? -1 : 1},{scale:lifted && !reduceMotion ? 1.12 : 1}]}} />
    {!!reaction && <View pointerEvents="none" style={{position:'absolute',bottom:size + 4,alignSelf:'center',alignItems:'center',width:150}}>
      <Label style={{fontSize:10,lineHeight:15,backgroundColor:colors.paper,padding:4,borderRadius:5}}>{reaction.text}</Label>
      <View style={{flexDirection:'row',alignItems:'center'}}>{reaction.food && <Sprite name={reaction.food} size={28} />}<Label style={{color:colors.coral}}>♥ ♥ ♥</Label></View>
    </View>}
    {(labels || lifted) && <Label style={{fontSize:10,lineHeight:14,textAlign:'center',backgroundColor:colors.paper}}>{animal.name}</Label>}
  </View>;
}
