import React, { useEffect, useState } from 'react';
import { Animated, Image, StyleSheet, View } from 'react-native';
import { Label, colors } from './ui';
export default function ScanOverlay({ uri, demo, success, reduceMotion }) {
  const [progress] = useState(() => new Animated.Value(0));
  const [burst] = useState(() => new Animated.Value(0));
  useEffect(() => {
    progress.setValue(0);
    const animation = Animated.timing(progress,{toValue:1,duration:650,useNativeDriver:false});
    if (!reduceMotion) animation.start(); else progress.setValue(1);
    return () => animation.stop();
  },[uri,reduceMotion]);
  useEffect(() => {
    if (!success || reduceMotion) return;
    burst.setValue(0); const animation = Animated.timing(burst,{toValue:1,duration:700,useNativeDriver:true}); animation.start();
    return () => animation.stop();
  },[success,reduceMotion]);
  return <View pointerEvents="none" style={[StyleSheet.absoluteFill,{zIndex:5}]}>
    <Image source={{uri}} style={StyleSheet.absoluteFill} resizeMode="contain" />
    <View style={[StyleSheet.absoluteFill,{borderWidth:3,borderColor:colors.gold,margin:10}]} />
    {!success && !reduceMotion && <Animated.View style={{position:'absolute',left:12,right:12,height:2,backgroundColor:colors.gold,
      top:progress.interpolate({inputRange:[0,1],outputRange:['8%','82%']})}} />}
    <View style={{position:'absolute',left:18,right:18,bottom:12,backgroundColor:colors.paper,padding:8}}>
      <Label style={{fontSize:12,textAlign:'center'}}>{success || (demo ? 'Simulated scan…' : 'Preparing photo…')}</Label>
      {!success && <Animated.View style={{height:4,backgroundColor:colors.forest,width:progress.interpolate({inputRange:[0,1],outputRange:['0%','100%']})}} />}
    </View>
    {!!success && !reduceMotion && <><Animated.View style={[StyleSheet.absoluteFill,{backgroundColor:'#fffceb',opacity:burst.interpolate({inputRange:[0,.2,1],outputRange:[.45,0,0]})}]} />
      {Array.from({length:8},(_,i) => <Animated.View key={i} style={{position:'absolute',left:'50%',top:'50%',width:6,height:6,backgroundColor:i % 2 ? colors.gold : colors.sage,
        opacity:burst.interpolate({inputRange:[0,1],outputRange:[1,0]}),transform:[
          {translateX:burst.interpolate({inputRange:[0,1],outputRange:[0,Math.cos(i * Math.PI / 4) * 80]})},
          {translateY:burst.interpolate({inputRange:[0,1],outputRange:[0,Math.sin(i * Math.PI / 4) * 80]})}]}} />)}</>}
  </View>;
}
