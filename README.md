# EcoGotchi 🌱

A pocket wilderness that grows through real-world environmental care. Native SwiftUI iPhone prototype for the CodeRED environment track.

## Run on iPhone or simulator

1. Install Xcode 16 or newer and open `EcoGotchi.xcodeproj`.
2. Select the EcoGotchi scheme and an iPhone simulator (iOS 17+), then Run.
3. For a physical iPhone, choose your Apple development team in Signing & Capabilities and set a unique bundle identifier if needed.

**Hackathon demo mode is on by default and works offline.** Tap Recycle and capture bin → item → disposal. Each photo shows a short simulated scan, then plays an original retro chime with haptics, a flash, pixel particles, and a success message. After the third photo, the app automatically awards **20 leaves** and clears one piece of virtual litter. No server, hotspot, Gemini key, or network connection is needed. Demo actions are labeled in the scan screen and journal, and their rewards persist normally.

Tap **Recycle → gear** to turn scan sounds off or switch from **Demo** to **AI review**. Sounds respect Silent Mode; flash and particles respect Reduce Motion. For optional Gemini review, follow [server setup](server/README.md). A physical iPhone is required for camera capture; use **Dev → Tools → Guided capture demo** on the simulator.

## Playable features

- One full-screen portrait habitat with a bottom-center camera button. Switch freely between Willow Grove, Coral Cove, and Snow Glade from the habitat title or **Shop → Habitats**.
- Friends and Shop have labeled buttons beside the bottom-center Recycle button.
- Find a bin, Journal, and Dev have direct shortcuts at the top; tapping the leaves balance also opens Shop.
- Friends shows the current habitat’s four pets; Shop has Food, Decorations, and Habitats sections; Journal shows actions across all habitats. Each panel has one title and a large close button.
- Four pollution states: Thriving (0 litter), Littered (1–2), Tarnished (3–4), Polluted (5–6).
- Willow Grove has three condition artworks. Coral Cove and Snow Glade each have four distinct condition backgrounds: **Thriving** (0 trash), **Littered** (1–2), **Tarnished** (3–4), and **Polluted** (5–6). Coral Cove progresses from clear water and colorful coral to murky water, algae, bleached coral, and sediment. Snow Glade progresses from bright powder to dirty slush, thinning pines, muddy snowbanks, and a hazy sky. Cleaning restores each scene through the same stages. Ocean bubbles, falling snow, litter, and haze add atmosphere.
- Twelve pixel pets: Pip, Fern, Clover, and Maple in the grove; Bubbles the clownfish, Shelly the turtle, Inky the octopus, and Fin the dolphin in the reef; Waddles the penguin, Flurry the arctic fox, Pebble the seal, and Snowdrop the hare in the snow.
- Retro stepped panels, pixel lettering, a segmented health meter, and gentle stepped animal movement.
- Each habitat has its own pixel animation layer: drifting leaves, fireflies, swaying grass, and pond ripples in Willow Grove; rising bubbles, swaying kelp, shifting light shafts, and sand shimmer in Coral Cove; snowfall, wind streaks, and ice sparkles in Snow Glade. Pollution dims healthy effects, turns leaves brown, and brings drifting haze and underwater sediment. Cleanup adds a gentle sparkle burst when you return from the camera.
- Habitat effects run independently of pet movement, pause behind panels and in the background, and resume without jumping ahead. Reduce Motion keeps a still frame and suppresses cleanup bursts. Dev → Tools provides separate **Habitat animations** and **Show habitat effects** switches.
- One new piece of litter every four hours, capped at six, including time away.
- One guided camera session: capture the bin (written label optional), then the item, then disposal into that same bin. The camera stays open between steps; an optional three-second shutter timer helps with the last photo.
- Demo automatically accepts all three captures and awards a fixed 20 leaves locally. In optional AI mode, inspect the three selected photos, then send them together in one Gemini request. The live preview stays on the phone; there is no continuous video upload. Gemini identifies the material, assesses visible evidence, and gives a sorting tip.
- A configurable server-wide limit defaults to 30 AI attempts per rolling 24 hours, including failures and rejected reviews. Gemini uses low thinking and a 2,048-token combined thought/answer cap; incomplete responses earn zero.
- In AI mode, only approved reviews clear one piece of virtual litter and earn material-based leaves: aluminum 30, steel 25, plastic/glass 20, cardboard 15, paper 10. Unclear/rejected reviews earn zero.
- The server prevents exact photo reuse and returns the same receipt on retry; saved receipt IDs prevent duplicate awards after relaunch.
- Each habitat starts with one friend and welcomes others at 1, 3, and 6 recycling actions performed there. Each keeps its own pollution clock and progress; the leaf wallet is shared. Old actions and progress belong to Willow Grove.
- Animals retreat at low habitat health without being removed from the collection.
- Twelve movable, lockable decorations: six woodland items, three reef items, and three snowy items. The Shop only displays decorations for the current habitat.
- Four consumable foods: berry basket (5 leaves), kelp bites (5), star crunch (8), and apple snack (4). Buy in **Shop → Food**, choose **Use**, and tap a pet. Each feeding consumes one snack, shows food and hearts, and saves its meal count. Feeding gives affection; recycling earns leaves and clears litter. Food availability varies by habitat.
- Progress, labeled demo rewards, AI-reviewed rewards, materials, and sorting tips persist locally between launches. Older self-reported entries remain clearly labeled.
- Woodland and snow pets walk on their own; ocean friends glide and bob through the water. They turn around and pause between trips. Tap for happy reactions, hopping, haptics, and pixel hearts. Pick them up and swing them, then release to fall under gravity and bounce gently onto the ground. Throws stay inside the visible habitat. Walking pauses during petting, while a panel is open, and when the app is inactive. Pet positions are playful scene state, not saved progress. VoiceOver users can pet animals or return them to their starting spots.
- Drag owned decorations to arrange the habitat. Tap one for a **Lock / Unlock** button; tap empty ground to dismiss its controls. **Shop → Decorations** also has per-item locks and **Reset this habitat’s positions & locks**, including when an item is covered by another sprite. Positions and locks save between launches, adapt to the visible play area, and remain isolated during developer preview.
- Per-photo scanning animation: frozen photo, corner brackets, a moving scan line, and a progress bar before the success message and chime. Demo scans remain explicitly simulated.
- VoiceOver descriptions for the habitat and reduced-motion support; Reduce Motion pauses pet roaming, places released pets directly on the ground, and removes swing/hops, floating hearts, scan sweep, and flashes.

Scenery preview, rendered from the app’s animation layer: [habitat animations](Art/habitat-animations-preview.gif).

## Demo walkthrough

Press Run in Xcode and tap the bottom-center **Recycle** button. The default **Demo** mode opens the camera without any connection setup. Take **Your bin → Your item → Disposal** photos. Each capture first freezes briefly under an animated scan line and progress bar, then shows “Successfully scanned bin”, “Successfully scanned item”, or “Successfully scanned disposal”, with a retro chime and pixel celebration. The final step has an optional three-second timer. After its celebration, 20 leaves are added automatically and one piece of habitat litter disappears. Return to your habitat to meet Fern. Watch the pets wander, tap to make them happy, or pick one up and release to watch it fall and bounce. Complete a second scan to afford wildflowers in **Shop → Decorations**. Drag the flowers into place, tap them and choose **Lock**, then reopen the Shop’s Decorations section to unlock them. Demo accepts all captured images without classifying their contents; no photos are uploaded or saved to the photo library.

Try **Shop → Food → Buy → Use**, then tap Pip or Fern to feed them. Open **Shop → Habitats** (or tap the habitat title) to visit Coral Cove and Snow Glade for free. Recycle in each new home to meet its remaining pets.

The gear opens **Scan settings**, including the sound switch and optional **AI review** mode. AI mode preserves the bin evidence and reward rules documented in [server setup](server/README.md). It does not silently fall back to demo rewards. If an unfinished camera session is interrupted, start the three captures again. Completed captures can finish after returning to the app; duplicate completion cannot award the same scan twice.

## Find a bin

Tap **Find a bin** at the top of the habitat. Choose **Use my location** and allow location access, or enter a city and state / ZIP code. Switch between 5, 10, and 25 km; tap a pin or list entry for listed materials, access information, source details, and **Directions** in Apple Maps. The habitat stays on the main screen.

No API key, Gemini tokens, or EcoGotchi server is needed. Recycling points come from [OpenStreetMap via Overpass](https://wiki.openstreetmap.org/wiki/Overpass_API); near Houston, the app also includes city-run facilities from the [City of Houston recycling dataset](https://services2.arcgis.com/LYMgRMwHfrWWEg3s/ArcGIS/rest/services/City_of_Houston_SWMD_Recycling_Disposal_Facilities/FeatureServer). The map labels each source. Locations explicitly marked private/restricted or disused are excluded. Missing materials and access details remain unknown; city listing does not establish residency eligibility or accepted items. Coverage varies and listings can change, so check the location’s signs/source before visiting. The map does not verify recycling or award leaves.

Location is requested once only after tapping **Use my location**, with no background tracking. Coordinates sent to Overpass are rounded to three decimal places (roughly 100 m); city/ZIP searches go through Apple Maps. The city supplement downloads the public facility list without sending coordinates. Search results are cached in memory for 15 minutes across panel openings, with clearly labeled offline results for up to 24 hours. The app observes server backoff responses, bounds the search radius, and cancels unfinished requests when the panel closes. Caches clear when the app quits. Public Overpass capacity is shared; a wider release should use a suitable hosted endpoint or shared server-side cache.

On an iPhone, check Allow Once / denied location, city search, the wider-radius empty state, pin/list selection, Apple Maps directions, and reopening after canceling a search. Map tiles and fresh location searches need internet access.

## Developer mode

Tap **Dev** at the top of the habitat. Its button turns yellow while preview mode is active. The **×** closes the panel while keeping the preview running. **Exit preview** at the top restores the original game, including normal elapsed-time pollution. Controls are grouped into Habitat, Friends, Rewards, and Tools.

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

Paid cosmetics and donations are a future concept only. There is no payment processing or real donation integration. The custom habitat, character atlas, and app icon are bundled locally; no artwork is fetched at runtime.

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
- `EcoGotchi/Assets.xcassets/AppIcon.appiconset/app-icon.png`: opaque 1024px Pip icon, packaged from the preserved generated master in `Design/pip-icon-master.png`.

Atlas content is cropped once in memory and drawn with nearest-neighbor interpolation. The original atlas uses hand-spaced `GameSprite.bounds`; the two new atlases use regular grids. Keep these layouts in sync if replacing artwork. Colors, stepped frames, button style, and the pixel wordmark are in `EcoGotchiApp.swift`. Existing saves remain compatible; older journal entries default to 20 earned leaves.

## Validation

Run the Foundation-only game logic checks without Xcode:

```sh
swiftc EcoGotchi/Models/HabitatState.swift Tests/HabitatStateChecks.swift -o /tmp/ecogotchi-checks
/tmp/ecogotchi-checks

swiftc EcoGotchi/Models/HabitatState.swift EcoGotchi/Models/RecyclingVerification.swift EcoGotchi/Models/HabitatStore.swift Tests/HabitatStoreChecks.swift -o /tmp/ecogotchi-store-checks
/tmp/ecogotchi-store-checks

swiftc EcoGotchi/Models/HabitatState.swift Tests/HabitatExpansionChecks.swift -o /tmp/ecogotchi-expansion-checks
/tmp/ecogotchi-expansion-checks

swiftc EcoGotchi/Models/RecyclingLocations.swift Tests/RecyclingLocationChecks.swift -o /tmp/ecogotchi-location-checks
/tmp/ecogotchi-location-checks

swiftc EcoGotchi/Models/RecyclingVerification.swift EcoGotchi/Models/RecyclingCaptureDraft.swift Tests/RecyclingCaptureChecks.swift -o /tmp/ecogotchi-capture-checks
/tmp/ecogotchi-capture-checks
```

Game and store checks cover condition boundaries, pollution timing, persistent/idempotent demo rewards, mode switching, reviewed rewards, malformed/duplicate receipt rejection, purchases, old saves, and developer-preview persistence isolation. Decoration checks cover saved positions and locks, rejected movement while locked, invalid coordinates, layout resets, and preview isolation. Expansion checks cover independent pollution and pet milestones, shared currency, food costs/limits, one-item consumption, meal persistence, wrong-habitat rejection, legacy-save migration, and preview isolation. Capture checks cover bin-first ordering, incomplete captures, identical-photo rejection, stable retry IDs/payloads, and restarting. Roaming, gravity, throw limits, stable landings, paused time steps, and sprite bounds can be checked with `swiftc EcoGotchi/Models/PetMotion.swift Tests/PetMotionChecks.swift -o /tmp/ecogotchi-pet-checks && /tmp/ecogotchi-pet-checks`. Run `npm test` in `server` for mocked Gemini and HTTP integration checks, including persistent review limits, concurrent last-slot requests, and truncated model responses. The iPhone Debug build compiles with Xcode. Camera, pet gestures, decoration controls, animation, haptic, and sound behavior still need physical-iPhone testing. On a phone, check a high drop and a fast flick, lock and unlock each decoration from both the scene and Shop, reopen the app to confirm layouts and food counts, switch among all three habitats, feed each starter pet, and try developer preview and Reduce Motion. Optional Gemini accuracy checks also need a configured server. Check permission denial, rejected/unclear reviews, network retry, reward persistence, and small-screen layouts before presenting.
