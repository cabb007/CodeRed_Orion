// Expo Go supplies its map configuration. Standalone Android builds need your Maps SDK key.
export default ({ config }) => ({
  ...config,
  plugins: [...config.plugins, ['react-native-maps', {
    ...(process.env.GOOGLE_MAPS_ANDROID_API_KEY ? { androidGoogleMapsApiKey: process.env.GOOGLE_MAPS_ANDROID_API_KEY } : {}),
  }]],
});
