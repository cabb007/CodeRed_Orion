import React, { useEffect, useState } from 'react';
import { AccessibilityInfo, Image, StyleSheet, View, useWindowDimensions } from 'react-native';
import { ANIMALS, condition, health } from './game';
import { art, colors, Sprite } from './ui';

export default function Habitat({ game, animate = true }) {
  const { width, height } = useWindowDimensions();
  const worldWidth = Math.max(width, height * 9 / 16);
  const worldHeight = Math.max(height, width * 16 / 9);
  const [tick, setTick] = useState(0);
  const [reduceMotion, setReduceMotion] = useState(true);
  useEffect(() => {
    let mounted = true;
    AccessibilityInfo.isReduceMotionEnabled().then(value => { if (mounted) setReduceMotion(value); });
    const event = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduceMotion);
    return () => { mounted = false; event.remove(); };
  }, []);
  useEffect(() => {
    if (reduceMotion || !animate) return;
    const timer = setInterval(() => setTick(t => 1 - t), 700);
    return () => clearInterval(timer);
  }, [reduceMotion, animate]);
  const state = condition(game.litter);
  const place = (name, x, y, fraction, offset = 0) => <Sprite key={`${name}-${x}`} name={name} size={worldWidth * fraction}
    style={{ position: 'absolute', left: worldWidth * x - worldWidth * fraction / 2,
      top: worldHeight * y - worldWidth * fraction / 2 + offset }} />;
  return <View style={StyleSheet.absoluteFill} pointerEvents="none" accessible accessibilityLabel={`Willow Grove, ${state}. Health ${health(game)} percent. ${game.litter} pieces of litter.`}>
    <View style={{ width: worldWidth, height: worldHeight, position: 'absolute', left: (width - worldWidth) / 2, top: (height - worldHeight) / 2 }}>
      <Image source={art[state]} style={{ width: worldWidth, height: worldHeight }} resizeMode="stretch" />
      {state === 'Littered' && <View style={[StyleSheet.absoluteFill, { backgroundColor: colors.muted, opacity: 0.06 }]} />}
      {game.ownedDecorations.includes('house') && place('house', 0.21, 0.51, 0.20)}
      {game.ownedDecorations.includes('flowers') && place('flowers', 0.16, 0.73, 0.14)}
      {game.ownedDecorations.includes('mushrooms') && place('mushrooms', 0.86, 0.66, 0.13)}
      {ANIMALS.map((animal, i) => game.actions.length >= animal.required && (state !== 'Polluted' || animal.id === 'pip') &&
        place(animal.id, [0.34, 0.65, 0.60, 0.27][i], [0.60, 0.57, 0.71, 0.74][i], 0.15, reduceMotion || !animate ? 0 : (tick + i) % 2 * -3))}
      {Array.from({ length: game.litter }, (_, i) => place(['cup', 'can', 'bottle', 'paper', 'bottle', 'cup'][i],
        [0.43, 0.73, 0.23, 0.56, 0.79, 0.41][i], [0.72, 0.65, 0.63, 0.61, 0.54, 0.53][i], 0.085))}
      {state === 'Thriving' && [0.3, 0.75, 0.47, 0.61, 0.23, 0.82].map((x, i) => <View key={i} style={{
        position: 'absolute', width: 3, height: 3, left: worldWidth * x, top: worldHeight * [0.47, 0.64, 0.72, 0.50, 0.66, 0.44][i],
        backgroundColor: colors.paper, opacity: reduceMotion ? 0.5 : (tick === i % 2 ? 0.8 : 0.25) }} />)}
    </View>
  </View>;
}
