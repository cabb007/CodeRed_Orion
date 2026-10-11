import React from 'react';
import { Image, Platform, Pressable, StyleSheet, Text, View } from 'react-native';

export const colors = { cream: '#f2f0d9', forest: '#244033', sage: '#cfdeaa', gold: '#facb63', paper: '#fffceb', coral: '#e07b57', muted: '#627464' };
export const art = {
  Thriving: require('../assets/grove-thriving.png'), Littered: require('../assets/grove-thriving.png'),
  Tarnished: require('../assets/grove-tarnished.png'), Polluted: require('../assets/grove-polluted.png'),
};
const names = ['pip', 'fern', 'clover', 'maple', 'flowers', 'mushrooms', 'house', 'leaf', 'bottle', 'can', 'cup', 'paper'];

export function Sprite({ name, size = 48, style }) {
  const index = Math.max(0, names.indexOf(name));
  const column = index % 4; const row = Math.floor(index / 4);
  const x = [40, 345, 638, 925][column]; const y = [165, 520, 873][row];
  const width = [272, 287, 289, 310][column]; const height = [333, 293, 273][row];
  const scale = size / Math.max(width, height);
  return <View accessible={false} style={[{ width: size, height: size, alignItems: 'center', justifyContent: 'center' }, style]}>
    <View style={{ width: width * scale, height: height * scale, overflow: 'hidden' }}>
      <Image source={require('../assets/sprites.png')} resizeMode="stretch" style={{ position: 'absolute', width: 1254 * scale,
        height: 1254 * scale, left: -x * scale, top: -y * scale }} />
    </View>
  </View>;
}
export function Label({ children, style, ...props }) {
  return <Text {...props} style={[styles.text, style]}>{children}</Text>;
}
export function Button({ children, onPress, secondary = false, disabled = false, style, accessibilityLabel }) {
  return <Pressable accessibilityRole="button" accessibilityLabel={accessibilityLabel} accessibilityState={{ disabled }}
    disabled={disabled} onPress={onPress} style={({ pressed }) => [styles.button, secondary && styles.secondary,
      disabled && { opacity: 0.45 }, pressed && { transform: [{ translateY: 2 }] }, style]}>
    <Label style={[styles.buttonText, { color: secondary ? colors.forest : colors.paper }]}>{children}</Label>
  </Pressable>;
}
export function Panel({ children, style }) { return <View style={[styles.panel, style]}>{children}</View>; }
export const styles = StyleSheet.create({
  text: { color: colors.forest, fontSize: 15, lineHeight: 22, fontFamily: Platform.select({ ios: 'Menlo', android: 'monospace', default: 'monospace' }) },
  heading: { fontSize: 24, lineHeight: 32, fontWeight: '800' },
  subheading: { fontSize: 18, lineHeight: 25, fontWeight: '700' },
  caption: { fontSize: 12, lineHeight: 18, color: colors.muted },
  button: { backgroundColor: colors.forest, minHeight: 48, justifyContent: 'center', alignItems: 'center',
    borderWidth: 2, borderColor: colors.forest, borderRadius: 5, paddingHorizontal: 16, paddingVertical: 12 },
  secondary: { backgroundColor: colors.sage },
  buttonText: { fontWeight: '700', textAlign: 'center', fontSize: 14 },
  panel: { backgroundColor: colors.paper, borderColor: colors.forest, borderWidth: 2, borderRadius: 5, padding: 16 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  stack: { gap: 16 },
  error: { color: '#a02f22', fontSize: 13, lineHeight: 20 },
  input: { borderWidth: 1, borderColor: colors.muted, borderRadius: 4, backgroundColor: '#ffffff', padding: 12,
    minHeight: 48, fontSize: 15, color: colors.forest },
});
