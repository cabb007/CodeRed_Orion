import { useEffect, useState } from 'react';
import { AccessibilityInfo, AppState } from 'react-native';
export function useSceneActive(enabled = true) {
  const [foreground,setForeground] = useState(AppState.currentState === 'active');
  useEffect(() => { const sub = AppState.addEventListener('change',s => setForeground(s === 'active')); return () => sub.remove(); },[]);
  return enabled && foreground;
}
export function useReduceMotion() {
  const [reduce,setReduce] = useState(true);
  useEffect(() => {
    let live = true;
    AccessibilityInfo.isReduceMotionEnabled().then(v => { if (live) setReduce(v); }).catch(() => {});
    const sub = AccessibilityInfo.addEventListener('reduceMotionChanged',setReduce);
    return () => { live = false; sub.remove(); };
  },[]);
  return reduce;
}
