# EcoGotchi 🌱

**Built with Swift/SwiftUI for native iOS and React Native/Expo for iOS and Android.**

A pocket wilderness that grows through real-world environmental care. This repository contains a React Native / Expo app for iOS and Android, plus the original native SwiftUI iPhone prototype for the CodeRED environment track.

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

1. Install Node.js 24 on your development computer (matching this repository's CI). Install or update [Expo Go](https://apps.apple.com/app/expo-go/id982107779) on an iPhone running iOS 16.4 or newer, and use an Expo Go version supporting this project's Expo SDK 57.
2. Check out `prototype`. From the repository root, install dependencies, sign into Expo CLI and start the iPhone launcher:

```powershell
# Windows PowerShell, from the repository root
cd .\mobile
npm.cmd ci
npx.cmd expo login
npm.cmd run iphone
```

On macOS/Linux, use `cd mobile`, `npm ci`, `npx expo login` and `npm run iphone` instead.

3. Open Expo Go on the iPhone and sign into the **same Expo account** as the terminal. This is required on a physical iPhone; check the terminal account with `npx.cmd expo whoami` (or `npx expo whoami` on macOS/Linux). See [Expo's sign-in requirements](https://docs.expo.dev/troubleshooting/expo-go-sign-in-required/).
4. Keep both devices connected to the internet. The iPhone launcher uses `expo start --go --tunnel --clear` to target Expo Go and avoid local Wi-Fi/firewall connection problems. Wait for **Tunnel ready**, scan the **new** QR code with the iPhone Camera app and open it in Expo Go. Keep the terminal running while using the app.
5. Allow camera access when recycling or adding a landmark, and allow foreground location when you tap **Use my location**. Demo recycling needs no EcoGotchi server or Gemini key.

Expo Go is a development host; a standalone iPhone app requires an iOS build and Apple signing. The Swift app has its own setup below.

### iPhone request timeout or blank screen

Stop the old Expo process with **Ctrl+C**, then run `npm.cmd run iphone` from `mobile/` (or `npm run iphone` on macOS/Linux). Until you pull this launcher update, the equivalent command is:

```powershell
npx.cmd expo start --go --tunnel --clear
```

Wait for **Tunnel ready** before scanning the new QR code; an earlier QR code can still point to the old LAN address. Tunnels require internet on both devices. The project's `@expo/ngrok` dependency is installed by `npm ci`. See [Expo tunneling](https://docs.expo.dev/more/expo-cli/#tunneling).

If the terminal reports a tunnel startup error, keep that exact error for troubleshooting. If Expo Go asks for sign-in, match the account on both devices, then retry; restart Expo after switching terminal accounts. If it reports an incompatible SDK, check that Expo Go supports SDK 57.

If the terminal finishes bundling for iOS but the phone still shows a blank screen, inspect the terminal and Expo Go error screen for a JavaScript or missing-module error. Report that text along with whether **Tunnel ready** and **iOS Bundled** appeared; this distinguishes connectivity problems from an app runtime failure.

## Set up React Native on an Android phone

1. Install Node.js 24 on the computer and a compatible Expo Go app on the Android phone.
2. From the checked-out repository root, run the same `cd mobile` → `npm ci` → `npx expo start --clear` sequence above. In Windows PowerShell, use `npm.cmd` and `npx.cmd`.
3. Connect both devices to the same Wi-Fi. Open Expo Go on Android and use its QR scanner to scan the terminal QR code. Keep the server running.
4. Grant camera and foreground-location permissions when their features request them. Use the tunnel command above if the phone cannot reach the computer over LAN.

Expo Go supplies the development map modules. A standalone Android build needs a Maps SDK for Android key through `GOOGLE_MAPS_ANDROID_API_KEY`, with the correct package/signing restrictions, plus Android build/signing configuration. See [mobile native configuration](mobile/README.md#native-configuration). The Swift app cannot be used on this phone.

## Set up Swift on an iPhone

1. Use a Mac with Xcode 16 or newer. Check out `prototype` and open `EcoGotchi.xcodeproj` from the repository root. Swift setup does not use npm, Expo Go or the `mobile/` folder.
2. Select the **EcoGotchi** scheme. Connect your iPhone to the Mac, unlock it and trust the computer when prompted.
3. In **Signing & Capabilities**, choose your Apple development team and a unique bundle identifier if needed. Select the connected iPhone as the run destination, enable Developer Mode on the phone if prompted, and click **Run**.
4. Use an iPhone running **iOS 17 or newer**. Grant Camera, Location or Local Network access when requested for the features you use. Demo recycling works offline; AI review and community sharing need the optional server connection.

For a simulator, choose an iPhone Simulator in Xcode and Run. The simulator does not provide a rear camera: open **Dev**, then choose **Tools → Guided capture demo**. Physical camera captures, permission behavior, sound/haptics and live map/sharing flows still require device testing. Android phones should use React Native.

## Run from Windows with React Native

The `mobile/` folder contains the React Native / Expo app. Run it from Windows on an iPhone or Android phone through a compatible Expo Go app. Demo mode needs no server. See [mobile setup and features](mobile/README.md) for installation, login, QR-code, tunnel, native-map configuration, optional AI review, and validation instructions. Run Expo from `mobile/`, where its `package.json` lives.

Install project dependencies before starting Expo. From the repository root:

```powershell
cd .\mobile
npm.cmd ci
npx.cmd expo start --clear
```

For a physical iPhone, sign into the same Expo account on the computer and in Expo Go, then use `npm.cmd run iphone` from `mobile/` and scan its new tunnel QR code. See [iPhone setup](#set-up-react-native-on-an-iphone) and [timeout troubleshooting](#iphone-request-timeout-or-blank-screen).

On later runs, start Expo from `mobile/`; repeat `npm.cmd ci` after pulling dependency or lockfile changes. The committed lockfile keeps Expo and React Native versions compatible.

If Expo says **"Cannot determine the project's Expo SDK version because the module expo is not installed"**, run `npm.cmd ci` in `mobile/` and then start Expo again. Accepting an `npx` prompt to download Expo installs a temporary CLI; it does not install this app's dependencies. If installation fails, resolve that npm error before retrying Expo.

The current React Native app includes:

- **Three habitats and twelve animals:** Willow Grove, Coral Cove and Snow Glade, with food, cosmetics, movable/lockable decorations, a shared leaf balance, journal and local saves.
- **Habitat reactions:** animal faces change for Thriving, Littered, Tarnished and Polluted habitats. Ambient effects respond to habitat condition.
- **Four animals at a time:** collision handling prevents animal overlaps, and all four can resume roaming after a drop. Drops show species-inspired written reactions, rather than recorded animal sounds.
- **Photo bin landmarks:** photograph a publicly accessible bin, confirm its map position and save it on the phone. Connecting the community server allows explicit sharing and removal of owned landmarks. Bin photos do not earn leaves.
- **Dev Mode:** open the panel and toggle it on to test a temporary copy. Gameplay and scan settings stay separate from real progress. Turning it off discards the copy; relaunch starts in real mode.
- **Recycle confirmation:** the main button says **RECYCLE**. Completing a saved demo scan displays **+20 leaves added to your total leaf points** and the updated total. AI reviews show their actual reward, and Dev Mode rewards are temporary.
- **Buy Leaves display:** Shop shows 100, 500 and 1,200 leaf packs first. A smaller note below them explains the plan to direct 80% of future purchases to preservation, conservation and wildlife reserve organizations. Buy buttons show a coming-soon message; no checkout, payment, purchased-leaf grant or donation transfer exists.

Random weather, an account-backed leaderboard, XP/tier progression, real payments and donation fulfillment remain roadmap work. This branch also ports the implemented React Native features into the SwiftUI app; see [native parity notes](NATIVE_PARITY.md).

The mobile suite currently has **63 tests**. See [mobile validation](mobile/README.md#validation) for commands and device-testing limits.

The remaining sections describe the native SwiftUI app and its server.

## Run the SwiftUI prototype on iPhone or simulator

1. Install Xcode 16 or newer and open `EcoGotchi.xcodeproj`.
2. Select the EcoGotchi scheme and an iPhone simulator (iOS 17+), then Run.
3. For a physical iPhone, choose your Apple development team in Signing & Capabilities and set a unique bundle identifier if needed.

**Hackathon demo mode is on by default and works offline.** Tap Recycle and capture bin → item → disposal. Each photo plays an original retro chime with haptics, a flash, pixel particles, and a success message. After the third photo, the app automatically awards **20 leaves** and clears one piece of virtual litter. No server, hotspot, Gemini key, or network connection is needed. Demo actions are labeled in the scan screen and journal, and their rewards persist normally.

Tap **Recycle → gear** to turn scan sounds off or switch from **Demo** to **AI review**. Sounds respect Silent Mode; flash and particles respect Reduce Motion. For optional Gemini review, follow [server setup](server/README.md). A physical iPhone is required for camera capture; use **Dev → Tools → Guided capture demo** on the simulator.

## SwiftUI features

- Willow Grove, Coral Cove and Snow Glade, each with four pets unlocked at 0, 1, 3 and 6 recycling actions in that habitat.
- Shared leaves and journal, with separate habitat pollution and unlocks. Existing Swift saves remain readable.
- Petting, feeding, drag/flick, gravity, bounce and roaming; a shared collision world supports at most four residents. Condition-dependent facial sprites and species-inspired drop speech bubbles match React Native.
- Four food types and twelve decorations. Positions and locks persist; reset affects the current habitat.
- Habitat-specific leaves/fireflies, reef bubbles/kelp and snow/wind, pollution artwork and cleanup effects. Motion pauses behind panels and in the background, and respects Reduce Motion.
- A native MapKit bin finder with foreground location, explicit city/ZIP searches, 5/10/25 km radii, OpenStreetMap and Houston public data, cache/fallback, attribution and Apple Maps directions.
- Photo bin landmarks saved on the phone, precise pin placement, optional explicit community sharing, photos and removal of owned landmarks. Landmarks never earn leaves.
- Bin → item → disposal capture, frozen scan progress, timer, success effects, sound and haptics. Saved rewards report the actual added leaves and updated total.
- Shop → Buy Leaves displays 100, 500 and 1,200 leaf packs, coming-soon buttons and a smaller note about the future 80% donation plan. Payments and donations are not implemented.
- Opening Dev creates a temporary preview of gameplay and scan settings. **Exit preview** restores saved progress and settings; old-mode callbacks cannot award progress.
- Demo scans earn 20 leaves and clear one litter item without a server. Optional approved AI reviews earn material-based leaves: aluminum 30, steel 25, plastic/glass 20, cardboard 15, paper 10.
- Receipt/submission deduplication across habitats, labeled journal entries, four-hour pollution, VoiceOver and Reduce Motion.

Scenery preview, rendered from the app's animation layer: [habitat animations](Art/habitat-animations-preview.gif).

See [native parity notes](NATIVE_PARITY.md) for implementation details and device checks.

## SwiftUI demo walkthrough

Press Run in Xcode and tap the bottom-center **Recycle** button. The default **Demo** mode opens the camera without any connection setup. Take **Your bin → Your item → Disposal** photos. Each capture first freezes briefly under an animated scan line and progress bar, then shows “Successfully scanned bin”, “Successfully scanned item”, or “Successfully scanned disposal”, with a retro chime and pixel celebration. The final step has an optional three-second timer. After its celebration, 20 leaves are added automatically and one piece of habitat litter disappears. Return to your habitat to meet Fern. Watch the pets wander, tap to make them happy, or pick one up and release to watch it fall and bounce. Complete a second scan to afford wildflowers in **Shop → Decorations**. Drag the flowers into place, tap them and choose **Lock**, then reopen the Shop’s Decorations section to unlock them. Demo accepts all captured images without classifying their contents; no photos are uploaded or saved to the photo library.

Try **Shop → Food → Buy → Use**, then tap Pip or Fern to feed them. Open **Shop → Habitats** (or tap the habitat title) to visit Coral Cove and Snow Glade for free. Recycle in each new home to meet its remaining pets.

The gear opens **Scan settings**, including the sound switch and optional **AI review** mode. AI mode preserves the bin evidence and reward rules documented in [server setup](server/README.md). It does not silently fall back to demo rewards. If an unfinished camera session is interrupted, start the three captures again. Completed captures can finish after returning to the app; duplicate completion cannot award the same scan twice.

## SwiftUI find a bin

Tap **Find a bin** at the top of the habitat. Choose **Use my location** and allow location access, or enter a city and state / ZIP code. Switch between 5, 10, and 25 km; tap a pin or list entry for listed materials, access information, source details, and **Directions** in Apple Maps. The habitat stays on the main screen.

No API key, Gemini tokens, or EcoGotchi server is needed. Recycling points come from [OpenStreetMap via Overpass](https://wiki.openstreetmap.org/wiki/Overpass_API); near Houston, the app also includes city-run facilities from the [City of Houston recycling dataset](https://services2.arcgis.com/LYMgRMwHfrWWEg3s/ArcGIS/rest/services/City_of_Houston_SWMD_Recycling_Disposal_Facilities/FeatureServer). The map labels each source. Locations explicitly marked private/restricted or disused are excluded. Missing materials and access details remain unknown; city listing does not establish residency eligibility or accepted items. Coverage varies and listings can change, so check the location’s signs/source before visiting. The map does not verify recycling or award leaves.

Location is requested once only after tapping **Use my location**, with no background tracking. Coordinates sent to Overpass are rounded to three decimal places (roughly 100 m); city/ZIP searches go through Apple Maps. The city supplement downloads the public facility list without sending coordinates. Search results are cached in memory for 15 minutes across panel openings, with clearly labeled offline results for up to 24 hours. The app observes server backoff responses, bounds the search radius, and cancels unfinished requests when the panel closes. Caches clear when the app quits. Public Overpass capacity is shared; a wider release should use a suitable hosted endpoint or shared server-side cache.

On an iPhone, check Allow Once / denied location, city search, the wider-radius empty state, pin/list selection, Apple Maps directions, and reopening after canceling a search. Map tiles and fresh location searches need internet access.

Use **Add a bin landmark** to capture a bin photo, confirm its position and save it on this phone. Sharing a saved landmark with the community is optional and explicit, and needs the configured EcoGotchi server connection. Community landmarks and their photos are separate from the public-location cache and earn no leaves. The server can host community bins without a Gemini key; AI photo review still requires that key.

## SwiftUI developer mode

Tap **Dev** at the top of the habitat to enter preview. Its button turns yellow while preview mode is active. Closing the panel keeps the temporary copy active; **Exit preview** restores saved gameplay, recycling mode and scan sounds, including normal elapsed-time pollution. Controls are grouped into Habitat, Friends, Rewards, and Tools.

The preview uses a temporary copy of the habitat. Test purchases and actions never overwrite the saved game, even if you close and relaunch the app mid-preview. Developer options reset when you exit. No special build setting is needed in this hackathon prototype.

Available controls:

- Choose any of the three habitats, pick its condition, set 0–6 trash, drop a piece, or clear it.
- Pause pollution, switch to 5/30/60-second intervals, or skip 4/24 hours.
- Set the current habitat’s completed-action count, unlock its four animals, hide individual animals, or override sheltering.
- Set leaves, tune the action reward and cleanup amount, simulate recycling, and add/remove decorations. Stock five of every food or adjust each snack’s inventory.
- Test the continuous camera flow or step through **Guided capture demo** using labeled sample artwork. Simulated reviews only change preview progress. The reward-only preview grants nothing. Developer mode never calls Gemini; exit preview and select AI review in Scan settings to test real reviews.
- Toggle **Pets roam on their own**, **Habitat animations**, **Show habitat effects**, element labels, and a placement grid; resize sprites. Turning roaming off still lets you pick up and drop pets. Pausing habitat animation preserves the scenery’s current frame; hiding effects removes the ambient layer. Preview decoration moves, locks, and resets are temporary.
- Load a thriving demo with all four local friends, 200 leaves, and a stocked food bag, or reset only the temporary preview. Habitat visits, food purchases, feeding, and layout changes stay inside the preview.

## Prototype boundaries

Demo scans are automatically accepted for gameplay and are not AI-verified. In optional AI mode, Gemini reviews visible photo evidence, **not proof of real disposal or downstream recycling**. Photos are uploaded only on submission, held in memory by the app/server, and discarded after processing or when the challenge closes. The server retains review results and image fingerprints; Google’s own data terms apply. Exact-duplicate checks and limits reduce casual reuse but do not defeat edited photos, staged actions, or modified clients. This remains a private hackathon prototype, with no cash-value rewards. See [server documentation](server/README.md) for privacy, retry behavior, limits, and setup. Game health and reward weights are fictional, not environmental-impact estimates.

Both apps have a display-only Buy Leaves section. Real-money leaf purchases and donations remain a future concept; there is no payment processing or donation integration. The custom habitat, character atlas, and app icon are bundled locally; no artwork is fetched at runtime.

## Custom art

Generated with the built-in image generation tool. Full prompts are saved in `Design/pixel-art-prompts.txt`, `Design/habitat-state-prompts.txt`, [Art/habitat-expansion-prompts.json](Art/habitat-expansion-prompts.json), and [Art/habitat-condition-prompts.json](Art/habitat-condition-prompts.json). The manifests record exact prompts and saved asset paths; the condition manifest also records the healthy reference image for each edit.

- `EcoGotchi/Assets.xcassets/GroveThriving.imageset/habitat.png`: thriving portrait scene, also used with slight desaturation and litter for the Littered state.
- `EcoGotchi/Assets.xcassets/GroveTarnished.imageset/habitat.png`: dull foliage and murky water.
- `EcoGotchi/Assets.xcassets/GrovePolluted.imageset/habitat.png`: dry ground, sparse foliage, and polluted water.
- `EcoGotchi/Assets.xcassets/WillowGrovePixel.imageset/willow-grove.png`: preserved original landscape artwork.
- `EcoGotchi/Assets.xcassets/EcoSpritesPixel.imageset/eco-sprites.png`: transparent atlas containing four animals, three decorations, a leaf currency icon, and four litter sprites.
- `EcoGotchi/Assets.xcassets/OceanReef.imageset/art.png`: thriving underwater reef background; `OceanLittered`, `OceanTarnished`, and `OceanPolluted` imagesets contain its progressively damaged states.
- `EcoGotchi/Assets.xcassets/SnowGlade.imageset/art.png`: thriving snowy glade background; `SnowLittered`, `SnowTarnished`, and `SnowPolluted` imagesets contain its progressively damaged states.
- `EcoGotchi/Assets.xcassets/FriendsAndFood.imageset/art.png`: transparent 4×3 atlas of eight new pets and four foods.
- `EcoGotchi/Assets.xcassets/HabitatDecor.imageset/art.png`: transparent 3×3 atlas of nine new decorations.
- `EcoGotchi/Assets.xcassets/GroveExpressions.imageset/art.png`, `OceanExpressions.imageset/art.png` and `SnowExpressions.imageset/art.png`: condition-dependent pet faces shared with the React Native artwork.
- `EcoGotchi/Assets.xcassets/AppIcon.appiconset/app-icon.png`: opaque 1024px Pip icon, packaged from the preserved generated master in `Design/pip-icon-master.png`.

Atlas content is cropped once in memory and drawn with nearest-neighbor interpolation. The original atlas uses hand-spaced `GameSprite.bounds`; the two new atlases use regular grids. Keep these layouts in sync if replacing artwork. Colors, stepped frames, button style, and the pixel wordmark are in `EcoGotchiApp.swift`. Existing saves remain compatible; older journal entries default to 20 earned leaves.

## SwiftUI and server validation

Run all native logic, persistence and networking checks on macOS:

```sh
bash scripts/check-swift.sh
```

The [Swift checks workflow](.github/workflows/swift-checks.yml) runs these checks and builds the iOS app for Simulator. Checks cover old saves, habitat progression, rewards/deduplication, food/layouts, pet physics/collisions, expression bounds, Dev Mode preferences and stale callbacks, capture order, public-location cache/backoff, phone landmarks and authenticated community requests. The [React Native checks workflow](.github/workflows/mobile-checks.yml) runs mobile tests, lint, exports for iOS/Android/web, and the server's mocked integration tests.

Run `npm test` in `server/` for mocked Gemini, HTTP and community-bin integration checks. Physical-iPhone camera, permissions, gesture appearance, sound/haptics and live sharing still need device testing. Optional Gemini accuracy checks need a configured server. See [native parity validation](NATIVE_PARITY.md#validation) for the device checklist.
