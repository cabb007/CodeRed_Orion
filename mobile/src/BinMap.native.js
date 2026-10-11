import React, { useEffect, useRef } from 'react';
import MapView, { Marker } from 'react-native-maps';
export default function BinMap({ area, locations, selected, onSelect }) {
  const map = useRef(null);
  const region = {latitude:area.latitude,longitude:area.longitude,latitudeDelta:area.radius * 2.5 / 111000,
    longitudeDelta:Math.min(360,area.radius * 2.5 / (111000 * Math.max(.1,Math.cos(area.latitude * Math.PI / 180))))};
  useEffect(() => { map.current?.animateToRegion(region,300); },[area.latitude,area.longitude,area.radius]);
  return <MapView ref={map} style={{height:260,width:'100%'}} initialRegion={region}
    accessibilityLabel="Nearby recycling locations" showsUserLocation={false}>
    {locations.map(l => <Marker key={l.id} identifier={l.id} coordinate={l.coordinate} title={l.name}
      description={l.kind} pinColor={selected === l.id ? '#e07b57' : '#244033'} onPress={() => onSelect(l.id)} />)}
  </MapView>;
}
