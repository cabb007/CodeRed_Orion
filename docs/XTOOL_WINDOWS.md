# Develop Recycli with xtool on Windows

This builds the **Swift iPhone app** from the same `Recycli/` sources as Xcode. React Native remains separate in `mobile/`. xtool installs on a physical iPhone; it does not provide Windows-hosted SwiftUI previews or Apple's iPhone Simulator.

## Prerequisites

- Ubuntu on WSL 2, Python 3.10+, Swift and xtool on Ubuntu's PATH.
- `xtool setup` completed with Apple authentication and a compatible Xcode `.xip` archive. `swift sdk list` should include `darwin`.
- An unlocked iPhone, a trusted USB connection and Developer Mode enabled when requested.

Use the versions specified by the [xtool installation guide](https://github.com/xtool-org/xtool/blob/main/Documentation/xtool.docc/Installation-Linux.md). Enter credentials directly in xtool. Recycli's personal Gemini key is entered in the app and saved in iPhone Keychain.

## Run Recycli

If the xtool Hello World app already runs, keep the **same Ubuntu terminal** open to retain its working `USBMUXD_SOCKET_ADDRESS` setting. You do not need to run `xtool setup` for each project.

For the first checkout, run each line separately **in Ubuntu**:

```bash
cd ~
git clone --branch prototype-2 --single-branch https://github.com/cabb007/CodeRed_Orion.git CodeRed_Orion
cd ~/CodeRed_Orion
bash scripts/run-xtool.sh
```

If `~/CodeRed_Orion` already exists, enter it instead of cloning over it. Check `git status`, switch to `prototype-2`, and pull if the worktree is clean:

```bash
cd ~/CodeRed_Orion
git status
git switch prototype-2
git pull --ff-only origin prototype-2
bash scripts/run-xtool.sh
```

The wrapper prepares assets and permissions, then calls `xtool dev`. Keep the phone unlocked during installation and Apple Devices open if using the Windows connection below. Open **Recycli** after installation; Demo is the default scan mode. Trust the development profile under **Settings → General → VPN & Device Management** if iOS asks. Revoked or expired profiles can require signing/installing again.

Keep the checkout in Ubuntu's home directory for Linux builds. Edit the original `Recycli/` files with VS Code's WSL extension (`code .` from Ubuntu) and install the Swift extension in the WSL workspace. There is no copied Swift implementation to synchronize.

Rebuild after edits from the repository root:

```bash
bash scripts/run-xtool.sh
```

Build without signing or installing with `bash scripts/run-xtool.sh build`. The app bundle is `xtool/Recycli.app`. Run the wrapper after a fresh clone or resource changes rather than bare `xtool dev`. Generated resources and build caches are ignored by Git.

The default `bundleID` in `xtool.yml` is `org.ecogotchi.app`, matching Xcode. If Apple reports it belongs to another team, choose your own unique ID there and rerun the wrapper. The generated Info.plist uses the same ID. Changing the ID installs a separate app with a separate local save and Keychain access.

## Windows Apple Devices connection

WSL USB passthrough can detect an iPhone yet fail at `[Connecting]` with `opTimeout` or a mux error. The [maintainer-linked workaround](https://github.com/xtool-org/xtool/issues/19) uses Windows' Apple Mobile Device service instead.

1. In PowerShell, use `usbipd list` to find the iPhone, then `usbipd detach --busid YOUR-BUSID`. Keep it plugged in.
2. Open [Apple Devices](https://apps.microsoft.com/detail/9np83lwlpz9k) on Windows, unlock the phone and trust the computer. Confirm Apple Devices recognizes it.
3. In Administrator PowerShell, check `Get-NetTCPConnection -LocalPort 27015 -State Listen` shows Apple's service at `127.0.0.1`.
4. With Ubuntu open and WSL's default NAT networking, run these PowerShell lines **in order**:

```powershell
$wslLink = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like '*WSL*' } | Select-Object -First 1
if (-not $wslLink) { throw "WSL adapter not found. Open Ubuntu first." }
$wslHostIP = $wslLink.IPAddress
netsh interface portproxy add v4tov4 listenaddress=$wslHostIP listenport=27015 connectaddress=127.0.0.1 connectport=27015
New-NetFirewallRule -DisplayName "xtool WSL Apple connection" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 27015 -LocalAddress $wslHostIP -InterfaceAlias $wslLink.InterfaceAlias
```

The firewall rule opens only that port on the WSL interface. Do not keep adding matching rules if one already exists. If WSL's host address changes after restarting, update the forwarding and rule for the current address.

5. In the Ubuntu terminal used for the build:

```bash
export USBMUXD_SOCKET_ADDRESS="$(ip route show default | awk '{print $3; exit}'):27015"
xtool devices
cd ~/CodeRed_Orion
bash scripts/run-xtool.sh
```

With mirrored networking already configured, the service can instead be reached at `USBMUXD_SOCKET_ADDRESS=127.0.0.1:27015`. Use the route that works on your setup. Leave the phone with Windows rather than reattaching it to usbipd. Set the environment variable again in each new Ubuntu terminal.

## Packaging and checks

If an older checkout fails with `cannot find type 'MapCameraPosition' in scope`, pull the latest `prototype-2` and rerun the wrapper. The package explicitly enables cross-import overlays so the Linux compiler loads SwiftUI's MapKit APIs. This addresses the same SwiftBuild configuration gap described in [xtool PR 361](https://github.com/xtool-org/xtool/pull/361). macOS/Xcode normally enables these overlays by default, so a successful Mac build alone does not establish that the Linux toolset is configured correctly. No SDK reinstall is needed for the package workaround.

`Package.swift` exposes the existing Swift app as the library product xtool expects, targets iOS 17+, and preserves Xcode's Swift 5 language mode. `xtool.yml` declares app-root resources. `scripts/prepare_xtool.py` stages the existing universal PNGs under their asset names, copies sounds and Gemini JSON, and derives an Info.plist with resolved bundle metadata and the original permission descriptions. This preserves existing `UIImage(named:)`, SwiftUI image and `Bundle.main` lookups without requiring Xcode's asset-catalog compiler on Windows.

Run `python3 -m unittest discover -s Tests -p 'xtool_*_test.py' -v` to check resources and permissions. CI runs these checks, the original Swift checks and Xcode Simulator build, and compiles the Swift package for iOS Simulator. CI does not exercise Apple signing or the physical phone connection. On the phone, check artwork, condition faces, scan sounds, camera/location permissions, maps and a real Gemini review separately.
