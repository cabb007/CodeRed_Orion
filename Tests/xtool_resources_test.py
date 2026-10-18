"""Check the resource/permission contract used by the real xtool app bundle."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location("prepare_xtool", ROOT / "scripts/prepare_xtool.py")
STAGING = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(STAGING)


class XtoolResourcesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / "Recycli", self.root / "Recycli")
        shutil.copyfile(ROOT / "xtool.yml", self.root / "xtool.yml")

    def prepare(self):
        with contextlib.redirect_stdout(io.StringIO()):
            return STAGING.prepare(self.root)

    def test_bundle_preserves_artwork_sounds_review_configuration_and_permissions(self):
        output = self.prepare()
        for imageset in (self.root / "Recycli/Assets.xcassets").glob("*.imageset"):
            image = json.loads((imageset / "Contents.json").read_text())["images"][0]["filename"]
            self.assertEqual((output / (imageset.stem + ".png")).read_bytes(), (imageset / image).read_bytes())
        for sound in (self.root / "Recycli/Sounds").glob("*.wav"):
            self.assertEqual((output / sound.name).read_bytes(), sound.read_bytes())
        self.assertEqual((output / "GeminiReview.json").read_bytes(), (self.root / "Recycli/Resources/GeminiReview.json").read_bytes())
        original = plistlib.loads((self.root / "Recycli/Info.plist").read_bytes())
        packed = plistlib.loads((output / "Info.plist").read_bytes())
        for key in ["NSCameraUsageDescription", "NSLocationWhenInUseUsageDescription", "NSLocalNetworkUsageDescription", "NSAppTransportSecurity"]:
            self.assertEqual(packed[key], original[key])
        self.assertEqual(packed["CFBundleExecutable"], "Recycli")
        self.assertEqual(packed["CFBundleIdentifier"], "org.ecogotchi.app")
        self.assertNotIn(b"$(", (output / "Info.plist").read_bytes())
        self.assertTrue((output / "AppIcon.png").is_file())

    def test_missing_resource_declaration_fails_before_an_incomplete_bundle(self):
        config = self.root / "xtool.yml"
        config.write_text(config.read_text().replace("  - .xtool-resources/GroveExpressions.png\n", ""))
        with self.assertRaisesRegex(ValueError, "GroveExpressions.png"):
            self.prepare()
        self.assertFalse((self.root / ".xtool-resources").exists())

    def test_custom_bundle_id_and_repeat_preparation(self):
        config = self.root / "xtool.yml"
        config.write_text(config.read_text().replace("org.ecogotchi.app", "com.example.recycli.test"))
        output = self.prepare()
        first = (output / "Info.plist").read_bytes()
        self.prepare()
        self.assertEqual((output / "Info.plist").read_bytes(), first)
        self.assertEqual(plistlib.loads(first)["CFBundleIdentifier"], "com.example.recycli.test")


if __name__ == "__main__":
    unittest.main()
