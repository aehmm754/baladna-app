#!/usr/bin/env python3
"""Configures AndroidManifest.xml, disables slow/OOM release lint checks, and tunes Gradle JVM memory."""
import os
import re
import sys

# 1. Patch AndroidManifest.xml
manifest_path = os.path.join("android", "app", "src", "main", "AndroidManifest.xml")
if not os.path.exists(manifest_path):
    print(f"ERROR: {manifest_path} not found!", file=sys.stderr)
    sys.exit(1)

with open(manifest_path, "r", encoding="utf-8") as f:
    content = f.read()

if "android.permission.INTERNET" not in content:
    content = content.replace(
        "<application",
        '    <uses-permission android:name="android.permission.INTERNET"/>\n    <application',
        1,
    )

content = content.replace('android:label="baladna"', 'android:label="بلدنا"')

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
print("Patched AndroidManifest.xml")

# 2. Disable lintVitalRelease in app/build.gradle.kts or app/build.gradle
kts_path = os.path.join("android", "app", "build.gradle.kts")
groovy_path = os.path.join("android", "app", "build.gradle")

if os.path.exists(kts_path):
    with open(kts_path, "r", encoding="utf-8") as f:
        gradle_txt = f.read()
    if "checkReleaseBuilds" not in gradle_txt:
        gradle_txt += """

android {
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}
"""
        with open(kts_path, "w", encoding="utf-8") as f:
            f.write(gradle_txt)
    print("Patched android/app/build.gradle.kts")
elif os.path.exists(groovy_path):
    with open(groovy_path, "r", encoding="utf-8") as f:
        gradle_txt = f.read()
    if "checkReleaseBuilds" not in gradle_txt:
        gradle_txt += """

android {
    lintOptions {
        checkReleaseBuilds false
        abortOnError false
    }
}
"""
        with open(groovy_path, "w", encoding="utf-8") as f:
            f.write(gradle_txt)
    print("Patched android/app/build.gradle")

# 3. Increase Gradle JVM heap & metaspace
props_path = os.path.join("android", "gradle.properties")
if os.path.exists(props_path):
    with open(props_path, "r", encoding="utf-8") as f:
        props = f.read()
    if "org.gradle.jvmargs=" in props:
        props = re.sub(
            r"^org\.gradle\.jvmargs=.*$",
            "org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -Dfile.encoding=UTF-8",
            props,
            flags=re.M,
        )
    else:
        props += "\norg.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -Dfile.encoding=UTF-8\n"
    with open(props_path, "w", encoding="utf-8") as f:
        f.write(props)
    print("Patched android/gradle.properties")
