import React, { useMemo, useState } from 'react';
import { Image, Pressable, StyleSheet, View, useWindowDimensions } from 'react-native';
import { useGame } from './GameProvider';
import { DECORATIONS, HABITATS, condition, habitatID, health, placement, residentAnimals } from './game';
import { habitatArt, colors, Label, Sprite } from './ui';
import InteractivePet from './InteractivePet';
import InteractiveDecoration from './InteractiveDecoration';
import Atmosphere from './Atmosphere';
import { createAnimalWorld } from './animalWorld';
import { residentSpriteSize } from './habitatResidents';
import { useReduceMotion, useSceneActive } from './sceneHooks';
export default function Habitat({ game, enabled = true }) {
  const store = useGame();
  const options = store.developer;
  const {width,height} = useWindowDimensions();
  const active = useSceneActive(enabled), reduceMotion = useReduceMotion();
  const [selected,setSelected] = useState(null);
  const id = habitatID(game), state = condition(game.litter), animals = residentAnimals(game,options);
  const worldWidth = Math.max(width,height * 9 / 16), worldHeight = Math.max(height,width * 16 / 9);
  const offsetX = (worldWidth - width) / 2, offsetY = (worldHeight - height) / 2;
  const playTop = Math.max(height * .33,Math.min(285,height * .48));
  const area = {x:10,y:playTop,width:Math.max(1,width - 20),height:Math.max(1,height - Math.min(205,height * .40) - playTop)};
  const world = useMemo(() => createAnimalWorld(),[id,width,height,options.spriteScale,store.isDeveloperMode]);
  const petSize = residentSpriteSize(area,worldWidth * .15 * options.spriteScale,animals.length);
  const place = (x,y) => ({x:worldWidth * x - offsetX,y:worldHeight * y - offsetY});
  const selectedID = active ? selected : null;
  return <View pointerEvents={active ? 'auto' : 'none'} style={StyleSheet.absoluteFill} accessibilityLabel={
    HABITATS.find(h => h.id === id).name + ', ' + state + '. Health ' + health(game) + ' percent. ' + game.litter + ' pieces of litter.'}>
    <Pressable accessibilityLabel="Habitat background" accessible={false} onPress={() => setSelected(null)} style={StyleSheet.absoluteFill}>
      <Image source={habitatArt[id][state]} style={{width:worldWidth,height:worldHeight,left:-offsetX,top:-offsetY}} resizeMode="stretch" />
    </Pressable>
    {state === 'Littered' && id === 'grove' && <View pointerEvents="none" style={[StyleSheet.absoluteFill,{backgroundColor:colors.muted,opacity:.06}]} />}
    {options.showAtmosphere && <Atmosphere key={id} habitat={id} litter={game.litter} width={width} height={height}
      active={active} animate={options.animateHabitat} reduceMotion={reduceMotion} />}
    {DECORATIONS.filter(d => d.habitat === id && game.ownedDecorations.includes(d.id)).map(d => <InteractiveDecoration key={id + '-' + d.id + '-' + store.isDeveloperMode}
      item={d} area={area} home={place(d.x,d.y)} size={worldWidth * d.scale * options.spriteScale} placement={placement(game,d.id)}
      selected={selectedID === d.id} onSelect={() => setSelected(d.id)} active={active} reduceMotion={reduceMotion} labels={options.showLabels} />)}
    {animals.map((animal,i) => <InteractivePet key={id + '-' + animal.id + '-' + store.isDeveloperMode}
        animal={animal} area={area} home={place([.34,.65,.60,.27][i],(id === 'ocean' ? [.52,.60,.67,.56] : [.68,.65,.73,.70])[i])}
        size={petSize} world={world} habitatCondition={state} active={active} reduceMotion={reduceMotion} roam={options.animateAnimals} labels={options.showLabels} />)}
    {Array.from({length:game.litter},(_,i) => {
      const p = place([.43,.73,.23,.56,.79,.41][i],[.72,.65,.63,.61,.54,.53][i]), size = worldWidth * .085 * options.spriteScale;
      return <View pointerEvents="none" key={i} style={{position:'absolute',left:p.x - size / 2,top:p.y - size / 2}}>
        <Sprite name={['cup','can','bottle','paper','bottle','cup'][i]} size={size} />
        {options.showLabels && <Label style={{fontSize:8,backgroundColor:colors.paper}}>Litter {i + 1}</Label>}
      </View>;
    })}
    {options.showGrid && <View pointerEvents="none" style={[StyleSheet.absoluteFill,{zIndex:250}]}>{Array.from({length:9},(_,i) => <React.Fragment key={i}>
      <View style={{position:'absolute',left:width * (i + 1) / 10,top:0,width:1,height,backgroundColor:'#ffffff88'}} />
      <View style={{position:'absolute',top:height * (i + 1) / 10,left:0,height:1,width,backgroundColor:'#ffffff88'}} />
    </React.Fragment>)}</View>}
  </View>;
}
