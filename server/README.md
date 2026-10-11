# EcoGotchi recycling review

The app now starts in offline **Demo** mode and does not need this server. For Gemini without a Mac, select **Actual → On iPhone** in Recycle → gear and enter your personal key. To use this server instead, select **Actual → Review server**. Demo awards are labeled separately and never call this server.

The iPhone sends two camera photos to this small server: the bin (include sorting icons, labels, or nearby signs if available), and the item. A written bin label is optional. Gemini identifies the material and returns a structured visual assessment and sorting tip. The server awards leaves only when the assessment satisfies all reward rules. An unavailable or unconfigured server never grants a fallback reward.

## Set up on your Mac

You need Node.js 22.13 or newer and a [Gemini API key from Google AI Studio](https://aistudio.google.com/api-keys). The server has no packages to install.

1. Open a terminal in this project's `server` folder and create the local configuration:

   ```sh
   cp .env.example .env
   ```

2. Open `.env` privately. Put your Gemini key after `GEMINI_API_KEY=`. Keep it out of the iPhone app and chat. `.env` is excluded from Git.

3. Generate a separate server access token:

   ```sh
   node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
   ```

   Copy that token into `ECOGOTCHI_ACCESS_TOKEN=`. This token lets your app use your server; it is not the Gemini key.

4. For an iPhone demo on the same trusted Wi-Fi, set `HOST=::` in `.env` (IPv4 + IPv6, including IPv6 hotspots). Start the server:

   ```sh
   npm start
   ```

   Keep this terminal running. Allow local network access if macOS asks. Default port: `8787`.

5. Find your Mac’s local name in a second terminal:

   ```sh
   scutil --get LocalHostName
   ```

   If it prints `Jinhua-MacBook`, the app address is `http://Jinhua-MacBook.local:8787`. An iPhone's `localhost` refers to the iPhone, so use the Mac’s `.local` name. If name lookup fails, the app supports private IPv4 addresses and **Use this Mac’s direct address** for the current development Mac.

6. Rebuild EcoGotchi in Xcode and run on your iPhone. Choose **Actual → Review server** in Scan settings. Exit developer preview if rewards should affect your saved game. Tap **Recycle → Set up AI connection** (or the gear). Enter the server address and the separate access token, then tap **Save & test connection**. This checks the server and access token without uploading photos or calling Gemini. When it succeeds, the access token is stored in the iPhone Keychain; tap **Done** to continue. This test does not validate Gemini's key, model, quota, or image review.

7. In one camera session, capture **Your bin → Your item**. The camera stays open between steps. Finish within ten minutes. Inspect the two photos and tap **Send for review** to upload them together in one request; the live preview is never uploaded. Approved actions add leaves and clear one piece of virtual litter; other results explain why no reward was earned.

The Mac and iPhone must share a network that allows devices to communicate. If connection fails, check the server is running, the `.local` name and token match, and EcoGotchi has Local Network permission in iPhone Settings. `http://your-mac.local:8787/health` in Safari checks server reachability, but does not validate the token or Gemini configuration. Local HTTP is unencrypted and is intended only for a trusted Wi-Fi demo; use an HTTPS address for hosting.

The app's **Save & test connection** uses authenticated `GET /v1/status` and reports the shared daily review budget. A wrong token, unreachable address, timeout, or an older server without this endpoint gets a specific setup message. Use `ECOGOTCHI_ACCESS_TOKEN` on the phone, not `GEMINI_API_KEY`. School and guest Wi-Fi may isolate devices; if the Mac's health page cannot be reached from the iPhone, use a network that allows peer connections or host the server at an HTTPS address. Repeated connection tests do not use Gemini tokens or reserve AI review attempts.

## Control AI usage

The app sends two resized JPEGs in a single request after the user taps **Send for review**. It does not stream camera frames or upload video. The server makes no automatic AI retries or continuations.

- `DAILY_REVIEW_LIMIT=30`: maximum Gemini attempts across **all devices using this server database** in a rolling 24 hours. Rejections, errors, and timeouts count because they can consume tokens. Set it to `0` to pause new reviews. Slots become available 24 hours after their attempt, rather than at midnight.
- `GEMINI_MAX_OUTPUT_TOKENS=2048`: cap on combined thought and answer tokens. The server also requests `thinking_level: low` and concise explanations. Incomplete/truncated responses grant no leaves. Valid configuration range: 512–8192; very small budgets can truncate the required JSON.
- Saved review results return on retry without spending another AI attempt, even when the limit is reached. Retrying a failed, uncached call can spend another attempt. Invalid uploads and already-rewarded photo duplicates are rejected before an AI attempt is reserved.
- Attempts are reserved in SQLite before the Gemini call, so concurrent requests and server restarts preserve the cap. Keep `server/data` intact. Separate databases/server deployments have separate limits.

Edit these values privately in `.env` and restart the server. This bounds request count and generated tokens for this server; it is not an account-wide monetary cap, and input image tokens still count toward Google usage. Requests made elsewhere with the same key are outside this counter. See [Google’s generation configuration](https://ai.google.dev/api/interactions-api) and [thinking token limits](https://ai.google.dev/gemini-api/docs/thinking).

Update the server and rebuild the iPhone app together: the required capture order is now bin, item.

## Leaves

| Main material | Leaves after approval |
| --- | ---: |
| Aluminum | 30 |
| Steel | 25 |
| Plastic | 20 |
| Glass | 20 |
| Cardboard | 15 |
| Paper | 10 |
| Unknown / other / unclear / rejected | 0 |

These are game balance values, not environmental-impact measurements. One submission covers one main item. Gemini never chooses the number of leaves. Rewards require a high-quality assessment of a recognizable recycling bin and a compatible, supported material, with no detected contamination or suspicious evidence. Readable text is optional: `binType` is `recycling`, `general_waste`, or `unknown`, while `acceptanceEvidence` is `printed_label`, `material_icon`, `nearby_sign`, `bin_appearance`, or `none`. Recognition from a recycling symbol, sorting opening, and combined bin/station design can qualify as `likely_compatible`. Appearance is never recorded as confirmed local acceptance. A plain wastebasket or color alone is insufficient. General-waste bins are rejected; unknown bins/evidence and unsupported materials receive no reward. Explicit visible restrictions override an apparent match. Check local collection rules even after an approved visual match; disposal is not verified.

Reward values live in `policy.mjs` and the app’s `RecycledMaterial.leaves`; update both together. Gemini’s model is configurable through `GEMINI_MODEL`, with `gemini-3.8-flash` as the current default. The adapter uses Google's [Interactions API](https://ai.google.dev/gemini-api/docs/interactions-overview), [image inputs](https://ai.google.dev/gemini-api/docs/image-understanding), and [structured output](https://ai.google.dev/gemini-api/docs/structured-output).

## Retry and duplicate behavior

The same submission ID and photos return the same saved receipt, even after a network failure or the capture window expires. The iPhone stores awarded receipt and submission IDs with the journal so retrying cannot award twice, including after relaunch. Identical photos that already earned leaves cannot earn again under another submission. Fingerprints and results persist in SQLite across server restarts; keep `server/data` intact. The server permits two simultaneous Gemini requests, six submissions per minute per network address, and ten approved rewards per installation in a rolling 24 hours.

A camera interruption or backgrounding before both captures discards the incomplete sequence. After submission, the app owns the review independently of the camera screen. You can return to the habitat, play, and open its review banner to see status/results. Approved rewards apply to the original habitat, once. Failed or cancelled reviews retain their two photos in memory for a manual retry; discarding the failed scan releases them. Photos are released on completion. Developer reviews remain isolated and are discarded on preview reset/exit; a live review completing during preview updates only the saved game. Keep the app open: iOS may suspend review when backgrounded, and terminating the app discards pending scans. There is no account-based receipt recovery.

## Privacy and prototype limits

Only two selected photos are resized and re-encoded in the app, then sent when the user taps **Send for review**. The continuous camera preview is neither recorded to disk nor streamed to the server. The app does not add them to the photo library. This server holds photos in memory during processing and does not write or log them. SQLite stores image hashes, review text, timestamps, random installation/submission IDs, and receipts. Gemini requests use `store: false` to disable Interactions history; this is not a promise of zero retention or training by Google. [Google’s API data terms](https://ai.google.dev/gemini-api/terms) still apply. Developer preview follows the app’s Demo/Actual selection. Actual sends real reviews and uses quota while keeping rewards temporary. Guided sample artwork and reward previews never upload photos.

AI checks item/bin compatibility; this flow does not capture or verify disposal or downstream recycling. Image hashes catch exact reuse, not altered photos or repeated staging. Capture timestamps and installation IDs are client-supplied. The shared token and local game balance are suitable for a private hackathon prototype, not a public reward service or real-money redemption. Public deployment would need authenticated accounts, an authoritative reward ledger, stronger capture/replay checks, and operational limits. Paid cosmetics, real donations, and cash-value rewards remain unimplemented.

## Tests

```sh
npm test
```

Tests use synthetic image bytes and mocked Gemini responses. They cover reward policy, insufficient evidence, request validation, structured-response parsing, authentication, idempotency, replay prevention, outages, concurrent duplicates, reward and AI-attempt limits, rolling-window resets, and restart persistence. They make no calls to Google. A real camera/Gemini check requires your key and device; classifier accuracy is not established by these tests.

## Direct address on an IPv6 hotspot

The server must listen with `HOST=::`; `HOST=0.0.0.0` only listens for IPv4. The development app has a **Use this Mac’s direct address** button in AI connection settings. Its `EcoGotchiLocalServerURL` in `EcoGotchi/Info.plist` points to the development Mac’s current IPv6 address, with a matching, specific `NSExceptionDomains` entry. Both must be updated and the app rebuilt if that IPv6 address changes after reconnecting or switching networks. The token remains in Keychain and is not part of the address. Private IPv4 addresses are also supported; the IPv4 translation address `192.0.0.2` on an IPv6 hotspot is not a peer-reachable LAN address and is not accepted.

The app keeps HTTPS for public hosts and permits HTTP only for local names, private/link-local IPv4 ranges, and the explicitly configured development IPv6 host. The scoped IP exceptions follow [Apple’s ATS configuration](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsexceptiondomains). Device isolation and Local Network permission can still prevent a connection; the direct address only bypasses name lookup.
