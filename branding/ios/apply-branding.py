# Copyright 2026 Kenny Root
# SPDX-License-Identifier: Apache-2.0
"""Prepare the generated Xcode runner before building or signing."""
from pathlib import Path
import json
import hashlib
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
l10n_dir = Path(__file__).resolve().parents[2] / "flutter_ui" / "lib" / "l10n"
info["CFBundleLocalizations"] = sorted(
    json.loads(path.read_text())["@@locale"] for path in l10n_dir.glob("app_*.arb")
)
info["NSLocalNetworkUsageDescription"] = "Connect to SSH servers and debug apps on your local network."
with info_path.open("wb") as stream:
    plistlib.dump(info, stream)

native_source = Path(__file__).resolve().parents[2] / "flutter_ui" / "platform" / "ios" / "AppDelegate.swift"
shutil.copyfile(native_source, runner / "AppDelegate.swift")
project_path = runner.parent / "Runner.xcodeproj" / "project.pbxproj"
project = project_path.read_text()
project = project.replace("AppDelegate.m", "AppDelegate.swift")
project = project.replace("lastKnownFileType = sourcecode.c.objc; path = AppDelegate.swift;",
                          "lastKnownFileType = sourcecode.swift; path = AppDelegate.swift;")
project = project.replace("\t\t\t\t97C146F31CF9000F007C117D /* main.m in Sources */,\n", "")
if "SWIFT_VERSION = " not in project:
    project = project.replace("CURRENT_PROJECT_VERSION = ", "SWIFT_VERSION = 5.0;\n\t\t\t\tCURRENT_PROJECT_VERSION = ")
# Folder resources preserve native strings and permission prompts in each locale.
for localized in sorted(native_source.parent.glob("*.lproj")):
    shutil.copytree(localized, runner / localized.name, dirs_exist_ok=True)
    ref_id = hashlib.sha256((localized.name + "-file").encode()).hexdigest()[:24].upper()
    build_id = hashlib.sha256((localized.name + "-resource").encode()).hexdigest()[:24].upper()
    if ref_id in project:
        continue
    project = project.replace("/* Begin PBXFileReference section */",
        f'/* Begin PBXFileReference section */\n\t\t{ref_id} /* {localized.name} */ = {{isa = PBXFileReference; lastKnownFileType = folder; path = {localized.name}; sourceTree = "<group>"; }};')
    project = project.replace("/* Begin PBXBuildFile section */",
        f'/* Begin PBXBuildFile section */\n\t\t{build_id} /* {localized.name} in Resources */ = {{isa = PBXBuildFile; fileRef = {ref_id}; }};')
    group_start = project.index("97C146F01CF9000F007C117D /* Runner */ = {")
    children = project.index("children = (", group_start) + len("children = (")
    project = project[:children] + f"\n\t\t\t\t{ref_id} /* {localized.name} */," + project[children:]
    phase_start = project.index("/* Begin PBXResourcesBuildPhase section */")
    files = project.index("files = (", phase_start) + len("files = (")
    project = project[:files] + f"\n\t\t\t\t{build_id} /* {localized.name} in Resources */," + project[files:]
project_path.write_text(project)
icons = runner / "Assets.xcassets" / "AppIcon.appiconset"
for item in json.loads((icons / "Contents.json").read_text())["images"]:
    target = icons / item["filename"]
    edge = round(float(item["size"].split("x")[0]) * float(item["scale"].removesuffix("x")))
    shutil.copyfile(source, target)
    if edge != 1024:
        subprocess.run(["sips", "-z", str(edge), str(edge), str(target)], check=True, stdout=subprocess.DEVNULL)
