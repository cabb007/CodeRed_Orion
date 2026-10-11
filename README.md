# EcoGotchi 🌱

**Built with Swift/SwiftUI for native iOS and React Native/Expo for iOS and Android.**

A pocket wilderness that grows through real-world environmental care. This repository contains a React Native / Expo app for iOS and Android, plus the original native SwiftUI iPhone prototype for the CodeRED environment track.

## Run from Windows with React Native

The `mobile/` folder contains the React Native / Expo app. Run it from Windows on an iPhone or Android phone through a compatible Expo Go app. Demo mode needs no server. See [mobile setup and features](mobile/README.md) for installation, login, QR-code, tunnel, native-map configuration, optional AI review, and validation instructions. Run Expo from `mobile/`, where its `package.json` lives.

The current React Native app includes:

- **Three habitats and twelve animals:** Willow Grove, Coral Cove and Snow Glade, with food, cosmetics, movable/lockable decorations, a shared leaf balance, journal and local saves.
- **Habitat reactions:** animal faces change for Thriving, Littered, Tarnished and Polluted habitats. Ambient effects respond to habitat condition.
- **Four animals at a time:** collision handling prevents animal overlaps, and all four can resume roaming after a drop. Drops show species-inspired written reactions, rather than recorded animal sounds.
- **Photo bin landmarks:** photograph a publicly accessible bin, confirm its map position and save it on the phone. Connecting the community server allows explicit sharing and removal of owned landmarks. Bin photos do not earn leaves.
- **Dev Mode:** open the panel and toggle it on to test a temporary copy. Gameplay and scan settings stay separate from real progress. Turning it off discards the copy; relaunch starts in real mode.
- **Recycle confirmation:** the main button says **RECYCLE**. Completing a saved demo scan displays **+20 leaves added to your total leaf points** and the updated total. AI reviews show their actual reward, and Dev Mode rewards are temporary.
- **Buy Leaves display:** Shop shows 100, 500 and 1,200 leaf packs first. A smaller note below them explains the plan to direct 80% of future purchases to preservation, conservation and wildlife reserve organizations. Buy buttons show a coming-soon message; no checkout, payment, purchased-leaf grant or donation transfer exists.

Random weather, an account-backed leaderboard, XP/tier progression, real payments and donation fulfillment remain roadmap work. These React Native additions do not automatically modify the SwiftUI app.

The mobile suite currently has **63 tests**. See [mobile validation](mobile/README.md#validation) for commands and device-testing limits.

The remaining sections describe the original SwiftUI prototype and its server.

## Run the SwiftUI prototype on iPhone or simulator

1. Install Xcode 16 or newer and open `EcoGotchi.xcodeproj`.
2. Select the EcoGotchi scheme and an iPhone simulator (iOS 17+), then Run.
3. For a physical iPhone, choose your Apple development team in Signing & Capabilities and set a unique bundle identifier if needed.

**Hackathon demo mode is on by default and works offline.** Tap Recycle and capture bin → item → disposal. Each photo plays an original retro chime with haptics, a flash, pixel particles, and a success message. After the third photo, the app automatically awards **20 leaves** and clears one piece of virtual litter. No server, hotspot, Gemini key, or network connection is needed. Demo actions are labeled in the scan screen and journal, and their rewards persist normally.

Tap **Recycle → gear** to turn scan sounds off or switch from **Demo** to **AI review**. Sounds respect Silent Mode; flash and particles respect Reduce Motion. For optional Gemini review, follow [server setup](server/README.md). A physical iPhone is required for camera capture; use **Dev → Tools → Guided capture demo** on the simulator.

## SwiftUI prototype features

- One full-screen portrait habitat with a bottom-center camera button; no tabs or scrolling dashboard.
- Friends and Decorate have labeled buttons beside the bottom-center Recycle button.
- Journal and Dev have direct shortcuts at the top; tapping the leaves balance also opens Decorate.
- Friends uses a compact collection grid; Decorate shows three item rows; Journal shows a short action list. Each panel has one title and a large close button.
- Four pollution states: Thriving (0 litter), Littered (1–2), Tarnished (3–4), Polluted (5–6).
- Matching portrait artwork changes the grass, foliage, water, and sky as the habitat deteriorates or recovers.
- Original Pip, Fern, Clover, and Maple sprites, matching decorations and litter, and a Pip app icon.
- Retro stepped panels, pixel lettering, a segmented health meter, and gentle stepped animal movement.
- One new piece of litter every four hours, capped at six, including time away.
- One guided camera session: capture the bin (written label optional), then the item, then disposal into that same bin. The camera stays open between steps; an optional three-second shutter timer helps with the last photo.
- Demo automatically accepts all three captures and awards a fixed 20 leaves locally. In optional AI mode, inspect the three selected photos, then send them together in one Gemini request. The live preview stays on the phone; there is no continuous video upload. Gemini identifies the material, assesses visible evidence, and gives a sorting tip.
- A configurable server-wide limit defaults to 30 AI attempts per rolling 24 hours, including failures and rejected reviews. Gemini uses low thinking and a 2,048-token combined thought/answer cap; incomplete responses earn zero.
- In AI mode, only approved reviews clear one piece of virtual litter and earn material-based leaves: aluminum 30, steel 25, plastic/glass 20, cardboard 15, paper 10. Unclear/rejected reviews earn zero.
- The server prevents exact photo reuse and returns the same receipt on retry; saved receipt IDs prevent duplicate awards after relaunch.
- Pip starts in the habitat; Fern, Clover, and Maple unlock at 1, 3, and 6 actions.
- Animals retreat at low habitat health without being removed from the collection.
- Earned leaves buy wildflowers, mushrooms, and a little hideaway.
- Progress, labeled demo rewards, AI-reviewed rewards, materials, and sorting tips persist locally between launches. Older self-reported entries remain clearly labeled.
- VoiceOver descriptions for the habitat and reduced-motion support.

## SwiftUI demo walkthrough

Press Run in Xcode and tap the bottom-center **Recycle** button. The default **Demo** mode opens the camera without any connection setup. Take **Your bin → Your item → Disposal** photos. Each capture shows “Successfully scanned bin”, “Successfully scanned item”, or “Successfully scanned disposal”, with a retro chime and pixel celebration. The final step has an optional three-second timer. After its celebration, 20 leaves are added automatically and one piece of habitat litter disappears. Return to your habitat to meet Fern. Complete a second scan to afford wildflowers in **Decorate**. Demo accepts all captured images without classifying their contents; no photos are uploaded or saved to the photo library.

The gear opens **Scan settings**, including the sound switch and optional **AI review** mode. AI mode preserves the bin evidence and reward rules documented in [server setup](server/README.md). It does not silently fall back to demo rewards. If an unfinished camera session is interrupted, start the three captures again. Completed captures can finish after returning to the app; duplicate completion cannot award the same scan twice.

## SwiftUI developer mode

Tap **Dev** at the top of the habitat. Its button turns yellow while preview mode is active. The **×** closes the panel while keeping the preview running. **Exit preview** at the top restores the original game, including normal elapsed-time pollution. Controls are grouped into Habitat, Friends, Rewards, and Tools.

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

The React Native app has a display-only Buy Leaves section. Real-money leaf purchases and donations remain a future concept; there is no payment processing or donation integration. The custom habitat, character atlas, and app icon are bundled locally; no artwork is fetched at runtime.

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
