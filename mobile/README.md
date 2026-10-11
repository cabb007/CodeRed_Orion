# EcoGotchi for iPhone from Windows

JavaScript React Native port of the SwiftUI prototype, built with Expo SDK 57. The Swift app and the existing Node verification server remain in the repository. Original art and scan chimes are reused under the repository license.

## Run on your iPhone with Expo Go

Install Node.js LTS on Windows and **Expo Go** from the iPhone App Store. The current Expo Go release must support SDK 57. Expo Go on physical iPhones requires the PC's Expo CLI and the phone to use the **same Expo account**. This development route does not need a Mac, Xcode, or paid Apple Developer membership.

In PowerShell, from the repository root:

```powershell
cd mobile
npm.cmd ci
npx.cmd expo login
npm.cmd start
```

Sign into Expo Go with that same account. Connect your PC and phone to the same Wi-Fi, then scan the terminal QR code with the iPhone Camera and choose **Open in Expo Go**. Keep the terminal running. JavaScript edits refresh the app.

If LAN access fails (guest Wi-Fi, Windows firewall, or different networks), stop the server with Ctrl+C and use:

```powershell
npm.cmd run iphone
```

This starts an Expo tunnel. It shares the development app; it does **not** tunnel the Gemini verification server. Tunnel reloads can be slower. If Expo Go reports an account mismatch, run `npx.cmd expo login` again and check the account on the phone. If it reports an unsupported SDK, update Expo Go and check its supported SDK before changing dependency versions.

Official instructions: [Windows setup](https://docs.expo.dev/get-started/create-a-project/) and [device login, QR codes and tunnels](https://docs.expo.dev/get-started/start-developing/).

## Play the demo

Demo mode is the default. Open **Recycle**, grant camera permission, and capture **Your bin → Your item → Disposal**. The last step has an optional three-second timer. Completing all three captures automatically earns 20 leaves and clears one piece of virtual litter. No API key or review server is needed; photos are not classified in demo mode.

- Pollution accumulates every four hours, including time away, up to six pieces.
- Pip starts unlocked. Fern, Clover, and Maple unlock at 1, 3, and 6 actions. Other animals shelter when the grove is polluted.
- Friends, Decorate, and Journal match the Swift prototype's collection, purchases, and action history.
- Progress uses local AsyncStorage. Writes are serialized; rewards appear after the save succeeds. Duplicate submission and receipt IDs cannot award twice. A last-known-good backup can recover a damaged save. Unrecoverable saves are kept until the user explicitly resets them.
- Dev uses an isolated temporary copy. Try the **Guided capture demo** with sample art, change litter, unlock friends, and try purchases. **Exit preview** restores the saved grove. Developer actions never call Gemini.
- Sounds respect iPhone Silent Mode. Habitat motion respects Reduce Motion; controls expose accessibility labels.

The browser preview (`npm.cmd run web`) supports the habitat, collection, shop, journal, and developer sample scan. AI review is disabled in the browser. Use the iPhone to test real camera, haptics, and sound behavior.

## Optional AI review from Windows

Use the existing server; its reward policy and Gemini adapter are unchanged. From another PowerShell terminal:

```powershell
cd server
Copy-Item .env.example .env
# Edit .env privately: GEMINI_API_KEY and a separate ECOGOTCHI_ACCESS_TOKEN.
npm.cmd start
```

Expose that server at an **HTTPS** address using your hosting or HTTPS tunnel provider. Keep its authentication enabled. This port deliberately requires HTTPS because Expo Go's native transport settings cannot be customized by `app.json`.

In **Recycle → Settings**, select **AI review**, enter the HTTPS base address (no path) and `ECOGOTCHI_ACCESS_TOKEN`, then **Save & test connection**. The separate access token is stored in SecureStore on the phone. Never enter the Gemini API key in the app. Testing checks server identity, authentication, and the shared review budget without spending a Gemini attempt. It does not validate Google's key or quota.

Capture all three photos within ten minutes. Inspect them, then **Send for review**. Only approved reviews earn material-based leaves. Rejections and unclear reviews earn zero. All Gemini limits, exact-reuse checks, and prototype limitations remain those in [server/README.md](../server/README.md).

Network retries reuse the same submission ID and photos while the scan screen stays open. A received receipt survives a local-save failure in memory, allowing a save retry without another Gemini request. Closing the screen or terminating the app discards the pending scan; account-based receipt recovery remains outside this port.

## Photos and saves

Expo Camera and ImageManipulator create temporary **app-cache files**. This port deletes originals after resizing and attempts to delete scan files when a scan finishes, restarts, or closes. An app crash can leave temporary cache files until the OS clears them. Images are not added to the photo library. Demo and preview never upload photos. AI uploads only the three prepared JPEGs on explicit submission, never the live camera preview.

React Native uses its own versioned local save; it does not import Swift UserDefaults or Keychain saves. Expo Go is a development host, not a standalone distributed EcoGotchi application. A separate App Store/TestFlight app can later be built with EAS and requires the appropriate Apple signing/distribution membership.

## Validation

```powershell
npm.cmd test
npm.cmd run lint
npm.cmd run export:ios
```

The JavaScript tests cover pollution, unlocks, purchases, save validation/backup recovery, serialized writes and failed-save retry, idempotent rewards, capture order/age, HTTPS settings, authenticated connection checks, and receipt validation. Existing server tests still run with `npm.cmd test` in `server`.

The iOS export verifies bundling, not installation or native device execution. Validate camera permission denial, backgrounding between captures, all three captures, shutter timer, Silent Mode, Reduce Motion, network retry, and rewards after relaunch on a physical iPhone. Real Gemini accuracy still requires a configured server and representative photographs.

`npm audit` currently reports upstream advisories in Expo/Metro, node-forge, uuid and the tunnel helper. Nonbreaking `npm audit fix` did not resolve all of them; its proposed force fix downgrades Expo incompatibly. Keep the development server on a trusted network and recheck upstream fixes before public production use.
