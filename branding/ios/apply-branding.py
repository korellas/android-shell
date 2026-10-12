# Copyright 2026 Kenny Root
# SPDX-License-Identifier: Apache-2.0
"""Prepare the generated Xcode runner before building or signing."""
from pathlib import Path
import json
import plistlib
import shutil
import subprocess
import sys

runner = Path(sys.argv[1]) / "Runner"
source = Path(__file__).parent / "TildeIcon1024.png"
info_path = runner / "Info.plist"
with info_path.open("rb") as stream:
    info = plistlib.load(stream)
info["CFBundleDisplayName"] = "Tilde"
info["CFBundleName"] = "Tilde"
with info_path.open("wb") as stream:
    plistlib.dump(info, stream)
icons = runner / "Assets.xcassets" / "AppIcon.appiconset"
for item in json.loads((icons / "Contents.json").read_text())["images"]:
    target = icons / item["filename"]
    edge = round(float(item["size"].split("x")[0]) * float(item["scale"].removesuffix("x")))
    shutil.copyfile(source, target)
    if edge != 1024:
        subprocess.run(["sips", "-z", str(edge), str(edge), str(target)], check=True, stdout=subprocess.DEVNULL)
