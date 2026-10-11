import { firstPosition } from './firstPosition';
export function locate(signal) {
  if (!navigator.geolocation) return Promise.reject(new Error('Location is unavailable in this browser. Search by city or ZIP instead.'));
  return firstPosition((success, failure) => {
    const id = navigator.geolocation.watchPosition(position => success(position.coords), e => {
      const error = new Error(e.code === 1 ? 'Location access is off. Allow it in your browser, or search by city or ZIP.' : 'Location is unavailable. Search by city or ZIP instead.');
      if (e.code === 1) error.code = 'LOCATION_DENIED';
      failure(error);
    }, { enableHighAccuracy: false, timeout: 15000, maximumAge: 60000 });
    return { remove: () => navigator.geolocation.clearWatch(id) };
  }, { signal });
}
