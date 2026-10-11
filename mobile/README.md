# EcoGotchi on iOS and Android

React Native / Expo SDK 57 port of the Swift prototype. The app includes Willow Grove, Coral Cove, Snow Glade, interactive pets, food, movable decorations, habitat effects, recycling capture, and a recycling-location finder. Swift and the Node verification server remain separate.

## Run on your phone from Windows

Install Node.js and a version of **Expo Go** that supports SDK 57 on your iPhone or Android phone. Start inside **mobile**, where package.json lives:

```powershell
cd C:\Users\cjwir\OneDrive\Documents\GitHub\CodeRed_Orion\mobile
npm.cmd install
npx.cmd expo start --clear
```

Connect the PC and phone to the same Wi-Fi. On iPhone, scan the terminal QR code with Camera; on Android, scan it with Expo Go. Keep the terminal running.

If Expo asks you to sign in, use `npx.cmd expo login` and sign into Expo Go with the same account. This command uses the terminal login flow. If your Windows browser launcher fails with `--browser`, use the terminal flow instead.

For networks where LAN discovery fails, stop Expo with Ctrl+C and run:

```powershell
npx.cmd expo start --tunnel --clear
```

The tunnel shares the development app. Your optional verification server needs its own reachable HTTPS address. See [Expo's device setup](https://docs.expo.dev/get-started/start-developing/).

Dependencies and the lockfile pin React Native **0.86.3** for this Expo SDK. Use the committed lockfile on a clean checkout with `npm.cmd ci`; do not replace the React Native version independently.

## Features

- **Three habitats:** use the habitat title or Shop → Habitats to switch. Pollution, pet unlocks, decorations, and positions are tracked for each habitat. Leaves and the journal are shared.
- **Twelve pets:** each habitat has four friends unlocked at 0, 1, 3, and 6 recycling actions in that habitat. Pets shelter at high pollution, apart from the starter.
- **Pet interaction:** tap for affection; drag and release to drop or flick. Pets roam and stay within the play area. Ocean motion uses reduced gravity. Motion pauses behind panels and in the background, and respects Reduce Motion.
- **Food:** buy one of four snacks with earned leaves, tap Use, then tap an available pet. Snacks and meal counts persist. Feeding does not award leaves or recycling progress.
- **Twelve decorations:** buy habitat-specific decorations, drag them into position, tap to lock/unlock, or reset the current layout in Shop. Normalized coordinates survive viewport changes and relaunches.
- **Habitat effects:** leaves, fireflies, grass and ripples; ocean bubbles, kelp, rays and sand; snow, wind and ice sparkles. Pollution changes the effects and artwork. Cleanup produces a short sparkle effect.
- **Find a bin:** request foreground location or submit a city/state or ZIP search; choose 5, 10 or 25 km. Native maps show pins and the list gives materials, access details, source links and directions. No location is requested until Use my location is tapped. OpenStreetMap data is supplemented by city-owned Houston facilities nearby.
- **Recycling:** capture Your bin → Your item → Disposal, with an optional three-second final shutter timer. A frozen scan overlay, progress, success effects, sound and haptics mark each capture.
- **Developer preview:** temporary habitats, pollution/timing, unlocks and pet visibility, wallets, custom rewards/cleanup, food stock, decorations, camera/sample/reward screens, animation controls, grid, labels and sprite scale. Exit preview restores saved progress.

These features match the existing Swift prototype's scope. Random weather, an account-backed leaderboard, an XP/tier progression system, paid points and donation payments are separate roadmap work.

## Demo and AI modes

Demo is the default. Three captures automatically earn 20 leaves and clear one piece of litter; demo does not classify photos or require a server. Developer sample captures use artwork and change only the temporary preview.

AI review uses the existing Node server and Gemini adapter. From the repository root in a separate terminal:

```powershell
cd server
Copy-Item .env.example .env
# Edit privately: GEMINI_API_KEY and a separate ECOGOTCHI_ACCESS_TOKEN.
npm.cmd start
```

Expose the server at an HTTPS address with authentication enabled. In Recycle → Settings select AI review, enter that HTTPS base address and the access token, and Save & test connection. The Gemini key stays on the server. The phone token uses SecureStore. Browser AI review is disabled.

Capture the same bin/item/disposal sequence within ten minutes, inspect the photos, and Send for review. Approved reviews earn material-based leaves. Network retries reuse the submission; a received receipt can retry a failed local save while that screen stays open. Closing the screen discards its pending scan. See [server/README.md](../server/README.md) for verification limits.

## Native configuration

Expo Go supplies the native map modules and hosting configuration. iOS uses Apple Maps. Standalone Android builds need a Maps SDK for Android key, configured through `GOOGLE_MAPS_ANDROID_API_KEY` in the build environment; `app.config.js` passes it to the react-native-maps plugin. Configure the key's Android package/signing restrictions for your build. See [Expo map configuration](https://docs.expo.dev/versions/latest/sdk/map-view/).

Camera permissions, foreground location, SecureStore and audio plugins are configured. Background location and microphone recording are disabled. Expo Go is a development host; installing a standalone app requires a development/distribution build and platform signing. Building iOS locally requires macOS/Xcode; EAS cloud builds are another route.

## Saves and location data

Existing React Native version-one saves keep their leaves, grove actions and decorations. New fields default safely. Mutations and backups are serialized; UI progress publishes after the write succeeds. Receipt/submission deduplication covers all habitats. A backup can recover a damaged save. React Native does not import Swift UserDefaults or Keychain saves.

Device coordinates are rounded to three decimals before a recycling search. OpenStreetMap Overpass receives those search coordinates and radius; its Nominatim service receives submitted place text. Houston's public city dataset is fetched without device coordinates. Fresh results are cached in memory for 15 minutes; labeled stale results may be shown for up to one day after an outage. Requests are cancelled when the finder closes, and public-service backoff is honored. Listings are not guarantees of acceptance; unknown access/materials remain labeled unknown.

City search is submitted explicitly, with no autocomplete. The public geocoder is rate limited and attributed. A larger deployment should use its own geocoding service; endpoints can be supplied to `createLocationService`. See the [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/).

Camera photos use temporary app-cache files, are resized, and are removed when scans finish/restart/close. A crash may leave files until the OS clears the cache. Demo/preview do not upload photos. AI uploads only the three prepared JPEGs after explicit submission.

## Validation

```powershell
npm.cmd test
npm.cmd run lint
npm.cmd run check:dependencies
npm.cmd run export:all
```

The 44 automated tests cover saved-data compatibility, per-habitat progression, feeding caps and concurrent writes, placements/locks, physics bounds, recycling-location parsing/cache/backoff, one-shot location cancellation, rewards and the existing verification client. Lint, dependency compatibility and web/iOS/Android exports passed for this update, including Hermes bytecode.

Device execution and visual UI behavior have not yet been verified. On both platforms, test foreground location permission denial, map pins/directions, camera/background/retry flows, all captures, feeding, drag/flick, relaunch persistence, developer-preview isolation, sound and Reduce Motion. The browser tool could not reach the validation server in this session. Browser preview supports demo/sample flows and a location list rather than a native map.

See [SWIFT_PARITY.md](SWIFT_PARITY.md) for the implementation mapping and remaining platform differences.
