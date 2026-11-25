#!/usr/bin/env python3
"""Adds INTERNET permission, Arabic app label, and URL launcher queries to AndroidManifest.xml."""
import os
import sys

manifest_path = os.path.join("android", "app", "src", "main", "AndroidManifest.xml")
if not os.path.exists(manifest_path):
    print(f"ERROR: {manifest_path} not found!", file=sys.stderr)
    sys.exit(1)

with open(manifest_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add INTERNET permission for release builds
if "android.permission.INTERNET" not in content:
    content = content.replace(
        "<application",
        '    <uses-permission android:name="android.permission.INTERNET"/>\n    <application',
        1,
    )

# 2. Set Arabic app display name
content = content.replace('android:label="baladna"', 'android:label="بلدنا"')

# 3. Add <queries> entries for tel and https (Call & WhatsApp)
extra_queries = """        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL" />
            <data android:scheme="tel" />
        </intent>"""

if "</queries>" in content and 'android:scheme="tel"' not in content:
    content = content.replace("</queries>", extra_queries + "\n    </queries>", 1)

with open(manifest_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Successfully patched AndroidManifest.xml")
