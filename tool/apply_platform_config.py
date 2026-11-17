#!/usr/bin/env python3
"""Adds the Android and iOS permissions this app needs.

Run once after `flutter create` (safe to run again):
    python3 tool/apply_platform_config.py
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent

# ── Android ────────────────────────────────────────────────────────────
manifest = root / "android/app/src/main/AndroidManifest.xml"
if manifest.exists():
    text = manifest.read_text()
    perms = [
        "android.permission.INTERNET",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.ACCESS_COARSE_LOCATION",
        "android.permission.CAMERA",
        "android.permission.POST_NOTIFICATIONS",
    ]
    add = "".join(
        f'    <uses-permission android:name="{p}"/>\n' for p in perms if p not in text
    )
    if add:
        text = re.sub(r"(<manifest[^>]*>\n)", lambda m: m.group(1) + add, text, count=1)
    if "<queries>" not in text:
        queries = (
            "    <queries>\n"
            '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n'
            '        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>\n'
            "    </queries>\n"
        )
        text = text.replace("<application", queries + "    <application", 1)
    manifest.write_text(text)
    print("Android manifest updated")
else:
    print("android/ not found - run flutter create first", file=sys.stderr)

# ── iOS ────────────────────────────────────────────────────────────────
plist = root / "ios/Runner/Info.plist"
if plist.exists():
    text = plist.read_text()
    keys = {
        "NSLocationWhenInUseUsageDescription": "Your location is used to check in at the job address and to show dispatch where you are.",
        "NSCameraUsageDescription": "The camera is used to take before and after photos of your work.",
        "NSPhotoLibraryUsageDescription": "Photos are used for job photos and your profile picture.",
    }
    add = "".join(
        f"\t<key>{k}</key>\n\t<string>{v}</string>\n" for k, v in keys.items() if k not in text
    )
    if add:
        text = text.replace("</dict>\n</plist>", add + "</dict>\n</plist>")
        plist.write_text(text)
    print("iOS Info.plist updated")
else:
    print("ios/ not found - run flutter create first", file=sys.stderr)
