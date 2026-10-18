#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/prepare_xtool.py
checks_dir="$(mktemp -d)"
device_id=""
cleanup() {
    if [[ -n "$device_id" ]]; then
        xcrun simctl shutdown "$device_id" >/dev/null 2>&1 || true
        xcrun simctl delete "$device_id" >/dev/null 2>&1 || true
    fi
    rm -rf "$checks_dir"
}
trap cleanup EXIT

# Exercise UIKit against the same loose PNG files shipped by xtool, not Assets.car.
python3 - "$checks_dir" <<'PY'
from pathlib import Path
import plistlib
import shutil
import sys

checks = Path(sys.argv[1])
fixture = checks / "ArtworkFixture.bundle"
shutil.copytree(".xtool-resources", fixture)
empty = checks / "EmptyFixture.bundle"
empty.mkdir()
for folder in (fixture, empty):
    (folder / "Info.plist").write_bytes(plistlib.dumps({
        "CFBundleIdentifier": "org.recycli.tests." + folder.stem,
        "CFBundleName": folder.stem,
        "CFBundlePackageType": "BNDL",
        "CFBundleVersion": "1",
    }))
PY

simulator_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
swiftc -swift-version 5 -parse-as-library -sdk "$simulator_sdk" \
    -target "$(uname -m)-apple-ios17.0-simulator" \
    Recycli/Models/HabitatState.swift Recycli/Models/GameArtwork.swift \
    Tests/AppArtworkChecks.swift -o "$checks_dir/check-artwork"
device_id="$(xcrun simctl create 'Recycli Artwork Checks' com.apple.CoreSimulator.SimDeviceType.iPhone-16)"
xcrun simctl boot "$device_id"
xcrun simctl bootstatus "$device_id" -b
xcrun simctl spawn "$device_id" "$checks_dir/check-artwork" \
    "$checks_dir/ArtworkFixture.bundle" "$checks_dir/EmptyFixture.bundle"
