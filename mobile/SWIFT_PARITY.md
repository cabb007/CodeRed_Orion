# Swift parity implementation

Scope: existing Swift prototype on main at `3e400d84c29544ab1d6db45b6fbc866f0b6ada77`, ported into the React Native app based on flush-out-features at `e82aa5dd6ebdaeb46b86a369d70cf501bda15b89`. Original React Native version-one saves remain supported.

| Swift source / behavior | React Native implementation |
| --- | --- |
| Models/HabitatState.swift: three habitats, pollution, action unlocks, shared leaves | src/catalog.js, src/game.js, src/GameProvider.js, src/Panels.js |
| HabitatState.swift: food inventory and pet meals | src/game.js, Shop food tab, src/InteractivePet.js |
| Views/InteractivePet.swift and Models/PetMotion.swift: petting, drag/flick, gravity, bounce, roaming | src/InteractivePet.js, src/motion.js, src/sceneHooks.js |
| Views/InteractiveDecoration.swift: saved positions and locks | src/InteractiveDecoration.js, src/game.js, Shop decoration tab |
| Views/HabitatAtmosphere.swift: habitat-specific ambient effects, pollution and cleanup | src/Atmosphere.js, src/Habitat.js, reused ocean/snow/sprite assets |
| Models/RecyclingFinder.swift, Models/RecyclingLocations.swift, Views/RecyclingMapView.swift: nearby/place searches, native map, directions, public data/cache | src/RecyclingFinder.js, src/deviceLocation.native.js, src/firstPosition.js, src/locations.js, src/BinMap.native.js |
| Views/ScanFeedback.swift and recycling camera flow: frozen capture, scan sweep/progress and success effects | src/ScanOverlay.js, src/Recycling.js |
| Views/DeveloperPanel.swift: temporary game controls and tool previews | src/Developer.js, src/GameProvider.js, App.js |
| Collection/shop/journal and original demo/AI verification | src/Panels.js, src/Recycling.js, existing src/verification.js and server |

The paths in the left column are under the Swift `EcoGotchi` directory. The original art and scan sounds are reused.

## Platform adaptations

iOS uses Apple Maps; Android uses Google Maps through react-native-maps. Native location comes from expo-location. Explicit place searches use Nominatim instead of Swift MapKit search. Browser preview uses a list and an OpenStreetMap link. Public-location parsing, privacy rounding, radius choices, cache/fallback, cancellation, and source attribution are implemented in JavaScript.

Habitat/scan effects are React Native views and animations; their behavior is ported, but pixel-identical rendering is not claimed. Existing camera, audio, haptics, secure token storage and HTTPS verification behavior are retained. Swift saves are not imported.

## Validation and remaining verification

44 tests passed. ESLint passed. Expo dependency checks passed. Web, iOS and Android exports passed, including native Hermes bytecode. The lockfile includes expo-location and react-native-maps and keeps React Native 0.86.3 compatible with Expo SDK 57.

No physical device, emulator/simulator or successful visual browser check was available. Native permission prompts, gestures, sound, map rendering/directions, relaunch behavior and live Gemini submissions still need the manual checks in README.md. Standalone Android maps require a provider key and signing configuration; iOS distribution requires platform signing.

This is an implementation of the prototype feature set, not a production-readiness or complete-device-validation claim. The new roadmap notes—random weather, backend leaderboard, XP tiers, paid cosmetic points and donations—were deferred at the user's request to finish Swift parity first.
