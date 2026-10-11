import * as Location from 'expo-location';
import { firstPosition } from './firstPosition';
export async function locate(signal) {
  const permission = await Location.requestForegroundPermissionsAsync();
  if (signal.aborted) { const error = new Error('Search cancelled.'); error.name = 'AbortError'; throw error; }
  if (permission.status !== 'granted') {
    const error = new Error('Location access is off. Search by city or ZIP instead, or open phone settings.');
    error.code = 'LOCATION_DENIED'; throw error;
  }
  return firstPosition((success, failure) => Location.watchPositionAsync(
    { accuracy: Location.Accuracy.Balanced, distanceInterval: 0 },
    position => success(position.coords),
    message => failure(new Error(message)),
  ), { signal });
}
