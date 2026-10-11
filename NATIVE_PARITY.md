# React Native features in Swift

The `prototype-2` integration combines latest main at `a3f557c396895e3f8bd3a749ca5d3e69134138eb` with prototype at `aa6536876add7269195dcfc24506ccffccaee03f`. It retains main’s Recycli project rename, direct Gemini API-key setup, two-photo visual-match policy and background review, alongside the React Native features previously integrated from `flush-out-features`. Main’s artwork, design records and presentation changes remain intact.

| React Native behavior | Native implementation |
| --- | --- |
| Three habitats, independent unlocks/pollution, shared wallet and journal | HabitatState, HabitatStore, CollectionView |
| Food, petting, drag/flick/bounce/roaming; movable decorations and locks | InteractivePet, PetMotion, InteractiveDecoration |
| Habitat effects and cleanup | HabitatAtmosphere, HabitatScene; bundled ocean/snow artwork |
| Four animal residents, collisions, condition faces and drop reactions | AnimalWorld, AnimalExpressions, expression atlases reused from mobile assets |
| Bin searches, cache/fallback and directions | RecyclingFinder, RecyclingLocations, RecyclingMapView |
| Photo bin landmarks, optional explicit sharing, photos and owned removal | CommunityBins, NewBinView, CommunityLandmarksView; same /v1/bins API and installation identity as native verification |
| Temporary Dev Mode gameplay/preferences and stale-callback rejection | HabitatSession, HabitatStore.modeSessionID, developer preview controls and scan cancellation |
| Frozen captures, progress, audio/haptics and saved reward totals | RecyclingCamera, RecyclingView, ScanFeedback |
| Buy Leaves packs and coming-soon donation copy | LeafShopView |

Swift files are under `Recycli/`; the build uses `Recycli.xcodeproj` and the `Recycli` scheme. React Native remains under `mobile/`.

## Native adaptations

MapKit supplies native maps, explicit place searches and Apple Maps directions. Tap the placement map to move a bin pin, or enter coordinates and apply them, then confirm the position. Foreground location and camera access are requested only after their buttons are tapped. Phone landmarks and JPEGs are stored atomically in an Application Support JSON file; shared phone copies remain available as labeled cache. Authentication reuses the native Keychain server connection. The existing native local-network connection option remains available alongside HTTPS.

Each platform keeps its own local saves. No Swift/React Native save import is implemented. Existing Swift saves default missing habitat/food/layout fields safely. Dev Mode is temporary across gameplay, scan mode and sounds; creating, sharing or removing saved landmarks is blocked. Opening Dev enters the temporary preview. Closing its controls keeps the copy running; Exit preview discards it.

Both apps capture bin → item and show the actual reward added plus updated total. Swift uses a personal Gemini API key in Keychain by default, with the review server as an option. React Native AI review uses the server. Swift can continue playing during a pending review and assigns its reward to the original habitat; React Native currently keeps the scan screen open. Swift Actual preview consumes real quota, while React Native preview always simulates.

Buy Leaves is a display-only feature with 100, 500 and 1,200 leaf packs. Random weather, accounts/leaderboards, XP tiers, real payments and donation fulfillment remain roadmap work in both stacks.

## Validation

Run `bash scripts/check-swift.sh` on macOS. It includes state/store/save compatibility, habitat expansion, pet physics, recycling captures, public data/cache, verification, direct Gemini policy, background review and native parity checks. The new checks exercise preference restoration, stale callbacks, collision separation and landing, expression bounds, landmark persistence/validation and corrupt-file preservation.

The Swift checks workflow builds the iOS app for a generic Simulator after these checks. React Native has cross-stack contract checks against the actual two-photo server policy, alongside its gameplay tests. Simulator compilation does not validate physical camera, permission prompts, gestures, map placement, audio, haptics or live sharing.

On a physical iPhone, check all three habitats and pollution faces, four-resident roaming/drop collisions, food/layout persistence, background interruptions, developer preview entry/exit and relaunch isolation, post-scan totals, local landmarks across relaunch, and community share/photo/remove with a test server. Sharing should never change leaves or progress. Check Silent Mode and Reduce Motion.
