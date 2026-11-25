#!/usr/bin/env python3
"""Configures Arabic display name, camera/photo permissions, and URL schemes in iOS Info.plist."""
import os
import plistlib
import sys

plist_path = os.path.join("ios", "Runner", "Info.plist")
if not os.path.exists(plist_path):
    print(f"ERROR: {plist_path} not found!", file=sys.stderr)
    sys.exit(1)

with open(plist_path, "rb") as f:
    data = plistlib.load(f)

data["CFBundleDisplayName"] = "بلدنا"
data["NSPhotoLibraryUsageDescription"] = "يحتاج تطبيق بلدنا للوصول إلى الصور لإرفاقها مع إعلاناتك."
data["NSCameraUsageDescription"] = "يحتاج تطبيق بلدنا للوصول إلى الكاميرا لتصوير إعلاناتك."

schemes = list(data.get("LSApplicationQueriesSchemes", []))
for scheme in ("tel", "https", "whatsapp"):
    if scheme not in schemes:
        schemes.append(scheme)
data["LSApplicationQueriesSchemes"] = schemes

with open(plist_path, "wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_XML, sort_keys=False)

print("Successfully patched ios/Runner/Info.plist")
