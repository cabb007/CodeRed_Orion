"""Stage app-root resources for xtool without requiring Apple's asset compiler."""
import json
from pathlib import Path
import plistlib
import re
import shutil


def prepare(root: Path) -> Path:
    root = root.resolve()
    app = root / "Recycli"
    config = (root / "xtool.yml").read_text(encoding="utf-8")
    bundle_match = re.search(r"^bundleID:\s*([A-Za-z0-9.-]+)\s*$", config, re.M)
    if not bundle_match:
        raise ValueError("Set a valid bundleID in xtool.yml")
    if not re.search(r"^product:\s*Recycli\s*$", config, re.M):
        raise ValueError("xtool.yml product must match the Recycli package product")

    files = {}
    for imageset in sorted((app / "Assets.xcassets").glob("*.imageset")):
        contents = json.loads((imageset / "Contents.json").read_text(encoding="utf-8"))
        images = [image for image in contents["images"] if image.get("filename")]
        if len(images) != 1 or images[0].get("idiom") != "universal":
            raise ValueError(f"{imageset.name}: xtool staging requires one universal image")
        image = (imageset / images[0]["filename"]).resolve()
        if not image.is_relative_to(imageset.resolve()) or image.suffix.lower() != ".png":
            raise ValueError(f"{imageset.name}: expected a PNG inside its image set")
        if image.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"{imageset.name}: invalid PNG")
        files[imageset.stem + ".png"] = image

    for sound in sorted((app / "Sounds").glob("*.wav")):
        files[sound.name] = sound
    files["GeminiReview.json"] = app / "Resources" / "GeminiReview.json"
    json.loads(files["GeminiReview.json"].read_text(encoding="utf-8"))

    declared = set(re.findall(r"^\s+- \.xtool-resources/([^/\s]+)\s*$", config, re.M))
    if declared != set(files):
        raise ValueError(
            "Update xtool.yml resources to match the source assets: "
            f"missing={sorted(set(files) - declared)}, extra={sorted(declared - set(files))}"
        )

    output = root / ".xtool-resources"
    if output.is_symlink() or output.resolve().parent != root:
        raise ValueError("The generated resource folder must be inside the project")
    output.mkdir(exist_ok=True)
    for name, source in files.items():
        destination = output / name
        if destination.is_symlink():
            raise ValueError(f"Refusing to overwrite a resource symlink: {name}")
        shutil.copyfile(source, destination)

    icon_set = app / "Assets.xcassets" / "AppIcon.appiconset"
    icon_info = json.loads((icon_set / "Contents.json").read_text(encoding="utf-8"))
    icon = (icon_set / next(i["filename"] for i in icon_info["images"] if i.get("filename"))).resolve()
    if not icon.is_relative_to(icon_set.resolve()):
        raise ValueError("App icon must be inside its asset set")
    icon_output = output / "AppIcon.png"
    plist_output = output / "Info.plist"
    if icon_output.is_symlink() or plist_output.is_symlink():
        raise ValueError("Generated icon and plist must not be symlinks")
    shutil.copyfile(icon, icon_output)

    info = plistlib.loads((app / "Info.plist").read_bytes())
    # xtool merges this plist literally; Xcode's $(...) placeholders are not expanded.
    info.update(
        CFBundleExecutable="Recycli",
        CFBundleName="Recycli",
        CFBundleIdentifier=bundle_match[1],
        UIDeviceFamily=[1],
        MinimumOSVersion="17.0",
    )
    encoded = plistlib.dumps(info, sort_keys=True)
    if b"$(" in encoded:
        raise ValueError("Unexpanded Xcode variable in generated Info.plist")
    plist_output.write_bytes(encoded)
    print(f"Prepared {len(files)} resources, app icon and iPhone permissions in {output}")
    return output


if __name__ == "__main__":
    prepare(Path(__file__).resolve().parent.parent)
