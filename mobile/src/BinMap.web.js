import React from 'react';
import { Linking } from 'react-native';
import { Button, Label, Panel } from './ui';
export default function BinMap({ area }) {
  return <Panel><Label>The locations below can be opened in your maps app.</Label><Button secondary onPress={() =>
    Linking.openURL('https://www.openstreetmap.org/#map=13/' + area.latitude + '/' + area.longitude)}>Open area map</Button></Panel>;
}
