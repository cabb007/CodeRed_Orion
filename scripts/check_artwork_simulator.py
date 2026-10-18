"""Run real UIKit image loading inside a Simulator app, with bounded subprocesses."""
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import tempfile


def run(*args, timeout=120, capture=False):
    print("Running:", " ".join(str(arg) for arg in args), flush=True)
    try:
        result = subprocess.run(args, check=False, timeout=timeout, text=True,
                                stdout=subprocess.PIPE if capture else None,
                                stderr=subprocess.STDOUT if capture else None)
    except subprocess.TimeoutExpired as error:
        if error.stdout:
            print(error.stdout.decode(errors="replace") if isinstance(error.stdout, bytes) else error.stdout, flush=True)
        raise
    if result.returncode and capture:
        print(result.stdout, flush=True)
    result.check_returncode()
    return result


def main():
    root = Path(__file__).resolve().parent.parent
    identifier = "org.recycli.tests.artwork"
    device = None
    try:
        with tempfile.TemporaryDirectory(prefix="recycli-artwork-") as folder:
            app = Path(folder) / "ArtworkChecks.app"
            shutil.copytree(root / ".xtool-resources", app)
            (app / "Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": identifier,
                "CFBundleExecutable": "ArtworkChecks",
                "CFBundleName": "ArtworkChecks",
                "CFBundlePackageType": "APPL",
                "CFBundleVersion": "1",
                "CFBundleShortVersionString": "1.0",
                "CFBundleSupportedPlatforms": ["iPhoneSimulator"],
                "MinimumOSVersion": "17.0",
                "UIDeviceFamily": [1],
                "LSRequiresIPhoneOS": True,
                "UILaunchScreen": {},
                "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
            }))
            empty = app / "EmptyFixture.bundle"
            empty.mkdir()
            (empty / "Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": identifier + ".empty",
                "CFBundleName": "EmptyFixture", "CFBundlePackageType": "BNDL",
                "CFBundleVersion": "1",
            }))
            sdk = run("xcrun", "--sdk", "iphonesimulator", "--show-sdk-path", capture=True).stdout.strip()
            run("swiftc", "-swift-version", "5", "-parse-as-library", "-sdk", sdk,
                "-target", platform.machine() + "-apple-ios17.0-simulator",
                str(root / "Recycli/Models/HabitatState.swift"),
                str(root / "Recycli/Models/GameArtwork.swift"),
                str(root / "Tests/AppArtworkChecks.swift"), "-o", str(app / "ArtworkChecks"),
                timeout=180)
            run("codesign", "--force", "--sign", "-", str(app))
            device = run("xcrun", "simctl", "create", "Recycli Artwork Checks",
                         "com.apple.CoreSimulator.SimDeviceType.iPhone-16", capture=True).stdout.strip()
            run("xcrun", "simctl", "boot", device)
            run("xcrun", "simctl", "bootstatus", device, "-b", timeout=180)
            run("xcrun", "simctl", "install", device, str(app))
            result = run("xcrun", "simctl", "launch", "--console", device, identifier,
                         capture=True, timeout=90)
            print(result.stdout, flush=True)
            if "Artwork runtime checks passed:" not in result.stdout:
                raise RuntimeError("Artwork app did not report successful UIKit checks")
    finally:
        if device:
            for command in ("shutdown", "delete"):
                try:
                    run("xcrun", "simctl", command, device, timeout=30)
                except (subprocess.SubprocessError, OSError) as error:
                    print("Simulator cleanup:", error, flush=True)


if __name__ == "__main__":
    main()
