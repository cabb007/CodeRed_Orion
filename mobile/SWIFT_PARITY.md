# Swift parity implementation

Scope: `prototype-2` combines main (`a3f557c`) and prototype (`aa65368`). The Swift app and Expo app remain separate. Original React Native version-one saves remain supported.

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

The paths in the left column are under the Swift `Recycli` directory. The original art and scan sounds are reused.

## Platform adaptations

iOS uses Apple Maps; Android uses Google Maps through react-native-maps. Native location comes from expo-location. Explicit place searches use Nominatim instead of Swift MapKit search. Browser preview uses a list and an OpenStreetMap link. Public-location parsing, privacy rounding, radius choices, cache/fallback, cancellation, and source attribution are implemented in JavaScript.

Habitat/scan effects are React Native views and animations; their behavior is ported, but pixel-identical rendering is not claimed. Existing camera, audio, haptics, secure token storage and HTTPS verification behavior are retained. Swift saves are not imported.

## Review behavior

Both apps now use two photos (bin → item), visual-match eligibility, material-based rewards and duplicate protection. Swift supports direct Gemini with a personal key in Keychain or the optional server. React Native uses the server, which needs its own Gemini key for reviews. Community landmarks work without Gemini.

Swift retains main’s store-owned pending review: return to the habitat while it runs, with rewards assigned to the originating habitat. React Native keeps review and retry state on the capture screen. Swift developer preview can call real Gemini if Actual is selected (quota applies); React Native preview always simulates. Gameplay and scan preference changes made in preview restore on exit.

## Validation and remaining verification

Run `npm test`, `npm run lint`, and `npm run export:all` from `mobile/`. These also run in CI. The cross-stack contract checks cover two-photo request ordering and server receipts, including visual-bin matches and rejected evidence.

Build and automated checks do not establish physical-device behavior. Native permission prompts, gestures, sound, map rendering/directions, relaunch behavior and live Gemini submissions still need the manual checks in README.md. Standalone Android maps require a provider key and signing configuration; iOS distribution requires platform signing.

This is an implementation of the prototype feature set, not a production-readiness or complete-device-validation claim. The new roadmap notes—random weather, backend leaderboard, XP tiers, paid cosmetic points and donations—were deferred at the user's request to finish Swift parity first.
