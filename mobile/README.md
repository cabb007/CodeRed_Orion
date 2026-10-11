# EcoGotchi on iOS and Android

**Built with Swift/SwiftUI for native iOS and React Native/Expo for iOS and Android.**

React Native / Expo SDK 57 port of the Swift prototype. The app includes Willow Grove, Coral Cove, Snow Glade, interactive pets, food, movable decorations, habitat effects, recycling capture, and a recycling-location finder. Swift and the Node verification server remain separate.

## Application stacks

| Layer | React Native app (`mobile/`) | Native iOS app (`EcoGotchi/`) |
| --- | --- | --- |
| Language and UI | JavaScript, React 19.2.3, React Native 0.86.3, Expo SDK 57 | Swift, SwiftUI; Xcode project targets iOS 17+ and uses Swift 5 language mode |
| Phone features | Expo Camera, Audio, Haptics, Location, Image Manipulator and FileSystem | AVFoundation camera/audio, UIKit images and haptics, CoreLocation |
| Maps | react-native-maps: Apple Maps on iOS, Google Maps on Android; list/OSM link on web | MapKit and Apple Maps |
| State and saves | React context/hooks, AsyncStorage, serialized repositories, native files for landmark photos | Combine ObservableObject, Codable, UserDefaults for gameplay, atomic Application Support file for landmarks |
| Credentials and requests | Expo SecureStore; authenticated fetch requests | Security/Keychain; URLSession with redirects blocked |
| Artwork and motion | React Native animation/gesture views and bundled pixel atlases | SwiftUI gestures, Canvas/TimelineView, shared pet physics/collision world and asset catalogs |
| Checks | Node test runner, ESLint, Expo exports | Standalone Swift checks and an iOS Simulator build in macOS CI |

Both apps use the optional Node.js server in `server/`, with built-in SQLite for review receipts and community bin landmarks, and Google Gemini for photo review. The Gemini API key stays on the server. Demo recycling works without a server; community sharing works without Gemini. These are separate app implementations and do not share local saves. Android and browser support come from the React Native app.

## Phone compatibility and framework choice

| Phone or preview | React Native / Expo (`mobile/`) | Swift / SwiftUI (`EcoGotchi/`) |
| --- | --- | --- |
| iPhone | Supported through a compatible Expo Go app or a signed native build | Supported on iOS 17+; install using macOS and Xcode |
| Android phone | Supported through a compatible Expo Go app or an Android build | Not supported; use the React Native app |
| Browser | Development preview with a location list; some native phone features differ or are unavailable | No browser app |
| Simulator/emulator | Requires the relevant platform tools; iOS Simulator requires macOS | iPhone Simulator on macOS/Xcode; camera capture requires a physical iPhone |

Windows can run the React Native development server for **both iPhone and Android**. Swift is the native **iPhone-only implementation** in this repository; it cannot be installed on Android or built locally from Windows. Use macOS/Xcode for Swift. The two implementations keep separate local saves.

## Set up React Native on an iPhone

1. Install Node.js 24 on your development computer (matching this repository's CI), and install Expo Go on your iPhone with support for this project's Expo SDK 57.
2. Check out `flush-out-features`. In a terminal at the repository root, install the app dependencies and start the server:

```powershell
# Windows PowerShell, from the repository root
cd .\mobile
npm.cmd ci
npx.cmd expo start --clear
```

On macOS/Linux, use `cd mobile`, `npm ci` and `npx expo start --clear` instead.

3. Put the computer and iPhone on the same Wi-Fi. Scan the terminal QR code with the iPhone Camera app and open it in Expo Go. Keep the development server running.
4. Allow camera access when recycling or adding a landmark, and allow foreground location when you tap **Use my location**. Demo recycling needs no server or Gemini key.

If LAN access fails, stop Expo and run `npx.cmd expo start --tunnel --clear` on Windows, or `npx expo start --tunnel --clear` on macOS/Linux. If Expo asks for login, use `npx.cmd expo login` (or `npx expo login`) and sign into Expo Go with the same account. Expo Go is a development host; a standalone iPhone app requires an iOS build and Apple signing.

## Set up React Native on an Android phone

1. Install Node.js 24 on the computer and a compatible Expo Go app on the Android phone.
2. From the checked-out repository root, run the same `cd mobile` → `npm ci` → `npx expo start --clear` sequence above. In Windows PowerShell, use `npm.cmd` and `npx.cmd`.
3. Connect both devices to the same Wi-Fi. Open Expo Go on Android and use its QR scanner to scan the terminal QR code. Keep the server running.
4. Grant camera and foreground-location permissions when their features request them. Use the tunnel command above if the phone cannot reach the computer over LAN.

Expo Go supplies the development map modules. A standalone Android build needs a Maps SDK for Android key through `GOOGLE_MAPS_ANDROID_API_KEY`, with the correct package/signing restrictions, plus Android build/signing configuration. See [native configuration](#native-configuration). The Swift app cannot be used on this phone.

## Set up Swift on an iPhone

1. Use a Mac with Xcode 16 or newer. Check out `flush-out-features` and open `EcoGotchi.xcodeproj` from the repository root. Swift setup does not use npm, Expo Go or the `mobile/` folder.
2. Select the **EcoGotchi** scheme. Connect your iPhone to the Mac, unlock it and trust the computer when prompted.
3. In **Signing & Capabilities**, choose your Apple development team and a unique bundle identifier if needed. Select the connected iPhone as the run destination, enable Developer Mode on the phone if prompted, and click **Run**.
4. Use an iPhone running **iOS 17 or newer**. Grant Camera, Location or Local Network access when requested for the features you use. Demo recycling works offline; AI review and community sharing need the optional server connection.

For a simulator, choose an iPhone Simulator in Xcode and Run. The simulator does not provide a rear camera: open **Dev**, turn **Dev Mode** on, then choose **Tools → Guided capture demo**. Physical camera captures, permission behavior, sound/haptics and live map/sharing flows still require device testing. Android phones should use React Native.

## Run on your phone from Windows

Install Node.js and a version of **Expo Go** that supports SDK 57 on your iPhone or Android phone. Start inside **mobile**, where package.json lives:

```powershell
# From the cloned repository root
cd .\mobile
npm.cmd ci
npx.cmd expo start --clear
```

Run the dependency-install command on first setup, before starting Expo. It installs every package from the committed lockfile, including Expo. Repeat it after pulling dependency or lockfile changes.

### Troubleshooting: Expo is not installed

If startup reports **"Cannot determine the project's Expo SDK version because the module expo is not installed"**, make sure you are inside `mobile/`, then run:

```powershell
npm.cmd ci
npx.cmd expo start --clear
```

Accepting `npx`'s prompt to download Expo only downloads a temporary CLI. The project still needs its own dependencies. If `npm.cmd ci` fails, resolve that npm installation error before restarting Expo. You do not need a global Expo install or an npm update to fix this missing-module error.

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
- **Twelve pets:** each habitat has four friends unlocked at 0, 1, 3, and 6 recycling actions in that habitat. At most four animals are active at once. Faces reflect Thriving, Littered, Tarnished or Polluted habitat conditions. Pets shelter at high pollution, apart from the starter.
- **Pet interaction:** tap for affection; drag and release to drop or flick. Animal collisions prevent overlaps while allowing all four residents to roam. Drops show species-inspired speech bubbles. Ocean motion uses reduced gravity. Motion pauses behind panels and in the background, and respects Reduce Motion.
- **Food:** buy one of four snacks with earned leaves, tap Use, then tap an available pet. Snacks and meal counts persist. Feeding does not award leaves or recycling progress.
- **Twelve decorations:** buy habitat-specific decorations, drag them into position, tap to lock/unlock, or reset the current layout in Shop. Normalized coordinates survive viewport changes and relaunches.
- **Habitat effects:** leaves, fireflies, grass and ripples; ocean bubbles, kelp, rays and sand; snow, wind and ice sparkles. Pollution changes the effects and artwork. Cleanup produces a short sparkle effect.
- **Find a bin:** request foreground location or submit a city/state or ZIP search; choose 5, 10 or 25 km. Native maps show pins and the list gives materials, access details, source links and directions. Add photo bin landmarks on the phone, or explicitly share them with a connected community server. No location is requested until Use my location is tapped. OpenStreetMap data is supplemented by city-owned Houston facilities nearby.
- **Recycling:** the main button says RECYCLE. Capture Your bin → Your item → Disposal, with an optional three-second final shutter timer. A frozen scan overlay, progress, success effects, sound and haptics mark each capture. After a demo reward is saved, the result confirms +20 leaves added and shows the updated total.
- **Buy Leaves display:** Shop shows three leaf packs, with a smaller 80% contribution note below them. Buttons show a coming-soon message. No payments, purchased leaves or donation transfers are implemented.
- **Dev Mode:** temporary habitats, pollution/timing, unlocks and pet visibility, wallets, custom rewards/cleanup, food stock, decorations, camera/sample/reward screens, animation controls, grid, labels and sprite scale. Toggle Dev Mode off to restore saved progress and settings.

The app ports the core Swift gameplay and adds photo bin landmarks, animal reactions/collisions, isolated Dev Mode and a display-only Buy Leaves section. Random weather, an account-backed leaderboard, an XP/tier progression system, real-money leaf purchases and donation fulfillment remain roadmap work.

## Demo and AI modes

Demo is the default. Three captures automatically earn 20 leaves and clear one piece of litter; demo does not classify photos or require a server. The RECYCLE button and demo scan heading do not advertise +20 leaves in advance. Once the reward is saved, the result says **+20 leaves added to your total leaf points** and displays your updated total. Duplicate scans do not claim a new award, and zero-reward results say no leaves were added. Dev Mode sample captures use artwork and affect only the temporary habitat and leaf balance.

AI review uses the existing Node server and Gemini adapter. From the repository root in a separate terminal:

```powershell
cd server
Copy-Item .env.example .env
# Edit privately: GEMINI_API_KEY and a separate ECOGOTCHI_ACCESS_TOKEN.
npm.cmd start
```

Expose the server at an HTTPS address with authentication enabled. In Recycle → Settings select AI review, enter that HTTPS base address and the access token, and Save & test connection. The Gemini key stays on the server. The phone token uses SecureStore. Browser AI review is disabled.

Capture the same bin/item/disposal sequence within ten minutes, inspect the photos, and Send for review. Approved reviews earn material-based leaves, and the result shows the actual awarded amount and updated total. Network retries reuse the submission; a received receipt can retry a failed local save while that screen stays open. Closing the screen discards its pending scan. See [server/README.md](../server/README.md) for verification limits.

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

The current suite contains **63 automated tests** covering saved-data compatibility, per-habitat progression, feeding caps and concurrent writes, placements/locks, animal expressions, collision bounds and four-resident roaming, photo bin storage/sharing, recycling-location parsing/cache/backoff, one-shot location cancellation, rewards, verification and Dev Mode isolation. The latest test and lint checks passed. iOS/Android/web exports, including Hermes bytecode, passed for the Dev Mode and Buy Leaves implementation. Later text/layout changes were lint-checked; exported bundles do not confirm physical-device behavior.

Device execution and visual UI behavior have not yet been verified. On both platforms, test foreground location permission denial, map pins/directions, camera/background/retry flows, all captures, feeding, drag/flick, relaunch persistence, Dev Mode isolation, sound and Reduce Motion. The browser tool could not reach the validation server in this session. Browser preview supports demo/sample flows and a location list rather than a native map.

See [SWIFT_PARITY.md](SWIFT_PARITY.md) for the implementation mapping and remaining platform differences.

## Photo bin landmarks

Open Find a bin → Add a bin landmark. Photograph the bin, use your location or enter coordinates, drag the pin to the bin, and confirm its position and public access. Choose materials from the bin label, add a name and notes, then Save landmark on this phone. Blue pins are personal drafts; they and their photos survive app restarts. Taking a photo does not upload it.

To share, configure Community map connection with your EcoGotchi server's HTTPS origin and ECOGOTCHI_ACCESS_TOKEN. Select the phone draft and tap Share with community. This explicitly publishes the photo, precise bin location, name, materials and notes to other phones using that server. Purple pins are Community · unverified; green pins are existing listings. Photos load when you select a landmark. You can remove your own shared landmark or phone draft. Failed uploads keep the same saved draft for an idempotent retry. Bin sharing works without AI review or a Gemini key and never adds leaves.

The app keeps shared phone copies for offline use, labeled as a phone cache when no current server result replaces them. Browser preview stores local drafts only. A standalone Android build still needs its Google Maps native configuration as described above. This feature currently uses prototype installation ownership rather than user accounts; see server/README.md.

## Animal expressions, collisions and drop reactions

All 12 animals have happy (Thriving), concerned (Littered), sad (Tarnished), and distressed (Polluted) facial sprites, in the habitat and collection cards. Petting, feeding and dropping briefly show a happy reaction before restoring the current habitat face. Existing shelter behavior in polluted habitats still applies. Use Dev Mode to switch litter levels and preview all states.

A shared collision world reserves space around animal sprites, including room for lift/tilt/bobbing. Initial placement, walking, dragging, throws and landings resolve animal-to-animal overlaps. Crowded rows can reposition neighbors; sprite sizes are limited to fit four animals in the viewport. Reduced-motion behavior remains supported. Decorations are not animal collision bodies.

Dropping shows species-inspired onomatopoeia in a speech bubble (Peep!, Ribbit!, Squeak!, Yip!, Blub!, Hiss!, Bloop!, Click-click!, Honk!, Yip-yip!, Arf!, Squeak-squeak!) and announces it to screen readers. These are playful written reactions, not recorded animal audio.

### Four-resident limit and roaming fix

Each active habitat displays at most four eligible animals, including Dev Mode. Visibility, unlock and shelter rules are applied before the cap. The collection still shows all animals. The shared collision world also refuses a fifth resident.

Animal sizes now account for the number of visible residents and leave room for all four to roam. Collision resolution separates animals sideways while preserving their height, so an animal cannot become stuck above its ground level in the falling state. Dropped animals still land and can resume roaming. Normal brief pauses, foreground activity, the roaming toggle and Reduce Motion remain respected.

## Dev Mode and Buy Leaves

Open **Dev Mode** from the main screen, then use its on/off switch. Opening the panel alone does not enable it. Turning it on copies your saved gameplay and preferences into memory; developer changes to leaves, food, recycling actions, unlocks, habitat state, decorations, layout and scan sounds stay in that copy. AI review is disabled and server credentials are not exposed in Dev Mode. Saved bin creation, sharing and removal are blocked.

Turning Dev Mode off discards its temporary changes. Turning it on again starts from your real save; relaunching always starts in real mode. Normal elapsed-time pollution still applies to your real habitat when real mode resumes. Switching waits for previously accepted real saves, and callbacks captured in an old mode cannot write into a new mode.

**Shop → Buy Leaves** displays packs of 100, 500 and 1,200 leaves first, under a short introduction. Tapping Buy displays a coming-soon message within the selected pack. This is a display-only feature: no checkout, external payment link, payment SDK, charge, currency grant or donation transfer is implemented. Prices remain unspecified.

A smaller caption below the packs states the future plan to direct **80% of each leaf purchase** to organizations supporting preservation, conservation and wildlife reserves. Keeping this note below the options gives the leaf packs priority. The caption also states that purchases and donations are coming soon. Organization selection, pricing, payment processing and donation fulfillment remain future work.

Dev Mode tests cover isolated gameplay/preferences, queued real saves, stale callbacks and mode transitions. A physical device should still be used to check the switch, settings restoration, post-scan reward confirmation and Buy Leaves interactions.
