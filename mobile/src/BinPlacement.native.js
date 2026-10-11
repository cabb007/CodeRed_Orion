import React from 'react';
import MapView, { Marker } from 'react-native-maps';
export default function BinPlacement({coordinate,onChange}) {
  return <MapView style={{height:230,width:'100%'}} region={{...coordinate,latitudeDelta:.004,longitudeDelta:.004}}
    accessibilityLabel="Confirm bin position. Tap the map or drag the pin." onPress={e => onChange(e.nativeEvent.coordinate)}>
    <Marker coordinate={coordinate} draggable onDragEnd={e => onChange(e.nativeEvent.coordinate)} title="Your bin" />
  </MapView>;
}
