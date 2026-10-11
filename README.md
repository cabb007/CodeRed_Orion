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

Expo Go supplies the development map modules. A standalone Android build needs a Maps SDK for Android key through `GOOGLE_MAPS_ANDROID_API_KEY`, with the correct package/signing restrictions, plus Android build/signing configuration. See [mobile native configuration](mobile/README.md#native-configuration). The Swift app cannot be used on this phone.

## Set up Swift on an iPhone

1. Use a Mac with Xcode 16 or newer. Check out `flush-out-features` and open `EcoGotchi.xcodeproj` from the repository root. Swift setup does not use npm, Expo Go or the `mobile/` folder.
2. Select the **EcoGotchi** scheme. Connect your iPhone to the Mac, unlock it and trust the computer when prompted.
3. In **Signing & Capabilities**, choose your Apple development team and a unique bundle identifier if needed. Select the connected iPhone as the run destination, enable Developer Mode on the phone if prompted, and click **Run**.
4. Use an iPhone running **iOS 17 or newer**. Grant Camera, Location or Local Network access when requested for the features you use. Demo recycling works offline; AI review and community sharing need the optional server connection.

For a simulator, choose an iPhone Simulator in Xcode and Run. The simulator does not provide a rear camera: open **Dev**, turn **Dev Mode** on, then choose **Tools → Guided capture demo**. Physical camera captures, permission behavior, sound/haptics and live map/sharing flows still require device testing. Android phones should use React Native.

## Run from Windows with React Native

The `mobile/` folder contains the React Native / Expo app. Run it from Windows on an iPhone or Android phone through a compatible Expo Go app. Demo mode needs no server. See [mobile setup and features](mobile/README.md) for installation, login, QR-code, tunnel, native-map configuration, optional AI review, and validation instructions. Run Expo from `mobile/`, where its `package.json` lives.

Install project dependencies before starting Expo. From the repository root:

```powershell
cd .\mobile
npm.cmd ci
npx.cmd expo start --clear
```

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
- An explicit Dev Mode switch copies gameplay and settings temporarily. Turning it off restores saved progress; old-mode callbacks cannot award progress.
- Demo scans earn 20 leaves and clear one litter item without a server. Optional approved AI reviews earn material-based leaves: aluminum 30, steel 25, plastic/glass 20, cardboard 15, paper 10.
- Receipt/submission deduplication across habitats, labeled journal entries, four-hour pollution, VoiceOver and Reduce Motion.

See [native parity notes](NATIVE_PARITY.md) for implementation details and device checks.

## SwiftUI demo walkthrough

Press Run in Xcode and tap the bottom-center **Recycle** button. The default **Demo** mode opens the camera without any connection setup. Take **Your bin → Your item → Disposal** photos. Each capture shows “Successfully scanned bin”, “Successfully scanned item”, or “Successfully scanned disposal”, with a retro chime and pixel celebration. The final step has an optional three-second timer. After its celebration, 20 leaves are added automatically and one piece of habitat litter disappears. Return to your habitat to meet Fern. Complete a second scan to afford wildflowers in **Shop → Decorations**. Demo accepts all captured images without classifying their contents; no photos are uploaded or saved to the photo library.

The gear opens **Scan settings**, including the sound switch and optional **AI review** mode. AI mode preserves the bin evidence and reward rules documented in [server setup](server/README.md). It does not silently fall back to demo rewards. If an unfinished camera session is interrupted, start the three captures again. Completed captures can finish after returning to the app; duplicate completion cannot award the same scan twice.

## SwiftUI developer mode

Tap **Dev** at the top of the habitat, then turn the **Dev Mode** switch on. Opening the panel alone does not enable it. Its button turns yellow while preview mode is active. Closing the panel keeps the temporary copy active; turning the switch off restores saved gameplay, recycling mode and scan sounds, including normal elapsed-time pollution. Controls are grouped into Habitat, Friends, Rewards, and Tools.

The preview uses a temporary copy of the habitat. Test purchases and actions never overwrite the saved game, even if you close and relaunch the app mid-preview. Developer options reset when you exit. No special build setting is needed in this hackathon prototype.

Available controls:

- Pick any habitat state, set 0–6 trash, drop a piece, or clear the grove.
- Pause pollution, switch to 5/30/60-second intervals, or skip 4/24 hours.
- Set completed-action count, unlock all animals, hide individual animals, or override sheltering.
- Set leaves, tune the action reward and cleanup amount, simulate recycling, and add/remove decorations.
- Test the continuous camera flow or step through **Guided capture demo** using labeled sample artwork. Simulated reviews only change preview progress. The reward-only preview grants nothing. Developer mode never calls Gemini; exit preview and select AI review in Scan settings to test real reviews.
- Toggle movement, sparkles/haze, element labels, and a placement grid; resize sprites.
- Load a thriving demo or reset only the temporary preview.

## Prototype boundaries

Demo scans are automatically accepted for gameplay and are not AI-verified. In optional AI mode, Gemini reviews visible photo evidence, **not proof of real disposal or downstream recycling**. Photos are uploaded only on submission, held in memory by the app/server, and discarded after processing or when the challenge closes. The server retains review results and image fingerprints; Google’s own data terms apply. Exact-duplicate checks and limits reduce casual reuse but do not defeat edited photos, staged actions, or modified clients. This remains a private hackathon prototype, with no cash-value rewards. See [server documentation](server/README.md) for privacy, retry behavior, limits, and setup. Game health and reward weights are fictional, not environmental-impact estimates.

Both apps have a display-only Buy Leaves section. Real-money leaf purchases and donations remain a future concept; there is no payment processing or donation integration. The custom habitat, character atlas, and app icon are bundled locally; no artwork is fetched at runtime.

## Custom art

Generated with the built-in image generation tool. Full prompts are saved in `Design/pixel-art-prompts.txt` and `Design/habitat-state-prompts.txt`.

- `EcoGotchi/Assets.xcassets/GroveThriving.imageset/habitat.png`: thriving portrait scene, also used with slight desaturation and litter for the Littered state.
- `EcoGotchi/Assets.xcassets/GroveTarnished.imageset/habitat.png`: dull foliage and murky water.
- `EcoGotchi/Assets.xcassets/GrovePolluted.imageset/habitat.png`: dry ground, sparse foliage, and polluted water.
- `EcoGotchi/Assets.xcassets/WillowGrovePixel.imageset/willow-grove.png`: preserved original landscape artwork.
- `EcoGotchi/Assets.xcassets/EcoSpritesPixel.imageset/eco-sprites.png`: transparent atlas containing four animals, three decorations, a leaf currency icon, and four litter sprites.
- `EcoGotchi/Assets.xcassets/AppIcon.appiconset/app-icon.png`: opaque 1024px Pip icon, packaged from the preserved generated master in `Design/pip-icon-master.png`.

Atlas content is cropped once in memory using `GameSprite.bounds`, then drawn with nearest-neighbor interpolation. Generated artwork uses hand-spaced rows rather than an exact grid; keep these bounds in sync if replacing the atlas. Colors, stepped frames, button style, and the pixel wordmark are in `EcoGotchiApp.swift`. Existing saves remain compatible; older journal entries default to 20 earned leaves.

## SwiftUI and server validation

Run the Foundation-only game logic checks without Xcode:

```sh
swiftc EcoGotchi/Models/HabitatState.swift Tests/HabitatStateChecks.swift -o /tmp/ecogotchi-checks
/tmp/ecogotchi-checks

swiftc EcoGotchi/Models/HabitatState.swift EcoGotchi/Models/RecyclingVerification.swift EcoGotchi/Models/HabitatStore.swift Tests/HabitatStoreChecks.swift -o /tmp/ecogotchi-store-checks
/tmp/ecogotchi-store-checks

swiftc EcoGotchi/Models/RecyclingVerification.swift EcoGotchi/Models/RecyclingCaptureDraft.swift Tests/RecyclingCaptureChecks.swift -o /tmp/ecogotchi-capture-checks
/tmp/ecogotchi-capture-checks
```

Game and store checks cover condition boundaries, pollution timing, persistent/idempotent demo rewards, mode switching, reviewed rewards, malformed/duplicate receipt rejection, purchases, old saves, and developer-preview persistence isolation. Capture checks cover bin-first ordering, incomplete captures, identical-photo rejection, stable retry IDs/payloads, and restarting. Run `npm test` in `server` for mocked Gemini and HTTP integration checks, including persistent review limits, concurrent last-slot requests, and truncated model responses. The iPhone Debug build compiles with Xcode. Camera, animation, haptic, and sound behavior still need physical-iPhone testing. Optional Gemini accuracy checks also need a configured server. Check permission denial, rejected/unclear reviews, network retry, reward persistence, and small-screen layouts before presenting.
