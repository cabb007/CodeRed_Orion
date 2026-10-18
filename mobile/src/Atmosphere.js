import React, { useEffect, useRef, useState } from 'react';
import { View } from 'react-native';
export default function Atmosphere({ habitat, litter, width, height, active, animate, reduceMotion }) {
  const [time,setTime] = useState(0);
  const previous = useRef(litter), pending = useRef(false);
  const [burst,setBurst] = useState(false);
  useEffect(() => { if (litter < previous.current) pending.current = true; previous.current = litter; },[litter]);
  const remaining = useRef(0);
  useEffect(() => {
    if (reduceMotion) pending.current = false;
    if (!active || !animate || reduceMotion) return;
    const timer = setInterval(() => {
      if (pending.current) { pending.current = false; remaining.current = 1.4; }
      remaining.current = Math.max(0,remaining.current - .08);
      setBurst(remaining.current > 0);
      setTime(t => (t + .08) % 600);
    },80);
    return () => clearInterval(timer);
  },[active,animate,reduceMotion]);
  const pollution = litter / 6;
  const elements = [];
  const dot = (key,x,y,w,h,color,opacity,rotate = 0,radius = 0) => elements.push(<View key={key} style={{
    position:'absolute',left:x,top:y,width:w,height:h,backgroundColor:color,opacity,borderRadius:radius,transform:[{rotate:rotate + 'deg'}]}} />);
  if (habitat === 'grove') {
    for (let i = 0; i < 9; i++) {
      dot('leaf' + i,((i * .131 * width + time * (7 + i % 3)) % width),height * (.34 + (i % 4) * .075) + Math.sin(time + i) * 12,7,4,
        pollution > .5 ? '#97733d' : '#8dbb58',.65,time * 28 + i * 30);
      dot('fly' + i,width * ((i * .113 + .13) % 1),height * (.42 + (i % 5) * .06) + Math.sin(time * .7 + i) * 8,3,3,'#fffcb1',
        (.2 + .5 * (1 + Math.sin(time * 2 + i)) / 2) * (1 - pollution));
      dot('grass' + i,width * ((i * .119 + .05) % 1),height * .79,3,14,'#73954b',.4 * (1 - pollution),Math.sin(time + i) * 12);
    }
    for (let i = 0; i < 3; i++) elements.push(<View key={'ripple' + i} style={{position:'absolute',left:width * .44,top:height * (.57 + i * .015),
      width:width * (.10 + Math.sin(time + i) * .015),height:4,borderBottomWidth:1,borderColor:'#ccecea',opacity:.35 * (1 - pollution)}} />);
  } else if (habitat === 'ocean') {
    for (let i = 0; i < 16; i++) {
      const y = height - ((i * 103 + time * (12 + i % 5)) % height);
      elements.push(<View key={'bubble' + i} style={{position:'absolute',left:width * ((i * .137 + .05) % 1) + Math.sin(time + i) * 5,top:y,
        width:5 + i % 4,height:5 + i % 4,borderWidth:1,borderColor:'#cbffff',borderRadius:10,opacity:.5 * (1 - pollution * .7)}} />);
      dot('sand' + i,width * ((i * .071 + .1) % 1),height * (.78 + i % 3 * .01),3,2,'#fff5b8',(.3 + Math.sin(time + i) * .2) * (1 - pollution));
    }
    for (let i = 0; i < 5; i++) {
      dot('kelp' + i,width * (.1 + i * .2),height * .70,5,70,'#337d66',.35 * (1 - pollution),Math.sin(time + i) * 8);
      dot('ray' + i,width * (i * .23),0,20,height * .65,'#e2ffff',.025 * (1 - pollution),15 + Math.sin(time * .3 + i) * 3);
    }
  } else {
    for (let i = 0; i < 25; i++) {
      dot('snow' + i,(width * ((i * .083 + .01) % 1) + Math.sin(time * .5 + i) * 18 + width) % width,
        (i * 79 + time * (10 + i % 8)) % height,3 + i % 3,3 + i % 3,pollution > .6 ? '#c5bba4' : '#ffffff',.75);
      if (i < 6) dot('wind' + i,((time * 20 + i * 71) % (width + 50)) - 50,height * (.30 + i * .07),30,1,'#ffffff',.3);
      if (i < 8) dot('ice' + i,width * ((i * .127 + .1) % 1),height * (.69 + i % 3 * .035),3,3,'#e7ffff',(.3 + Math.sin(time + i) * .25) * (1 - pollution));
    }
  }
  if (pollution > .3) for (let i = 0; i < 6; i++) dot('haze' + i,((i * 101 + time * 5) % (width + 150)) - 100,
    height * (.4 + i * .06),150,25,habitat === 'ocean' ? '#705e43' : '#7c806f',pollution * .065,0,20);
  if (burst && active && animate && !reduceMotion) for (let i = 0; i < 18; i++) dot('burst' + i,width * ((i * .173) % 1),height * (.4 + ((i * .139) % .38)),5,5,'#fff9af',.8);
  return <View pointerEvents="none" accessibilityElementsHidden importantForAccessibility="no-hide-descendants"
    style={{position:'absolute',width,height,overflow:'hidden'}}>{elements}</View>;
}
