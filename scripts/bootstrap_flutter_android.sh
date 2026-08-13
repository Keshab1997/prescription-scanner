#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/apps/mobile"
PACKAGE="com.rxscanlabs.prescriptionscanner"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK was not found. Install current stable Flutter (3.38.1+) first." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

flutter create \
  --platforms=android \
  --org com.rxscanlabs \
  --project-name prescription_scanner \
  "$TMP/prescription_scanner"

rm -rf "$APP/android"
cp -R "$TMP/prescription_scanner/android" "$APP/android"

python3 - "$APP" "$PACKAGE" <<'PY'
from pathlib import Path
import sys
app = Path(sys.argv[1])
package = sys.argv[2]
for path in app.rglob('*'):
    if path.is_file() and path.suffix in {'.kt', '.kts', '.gradle', '.xml'}:
        text = path.read_text(encoding='utf-8')
        text = text.replace('com.rxscanlabs.prescription_scanner', package)
        path.write_text(text, encoding='utf-8')

manifest = app / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8')
if 'android.permission.CAMERA' not in text:
    text = text.replace(
        '<application',
        '<uses-permission android:name="android.permission.CAMERA" />\n    <application',
        1,
    )
if 'login-callback' not in text:
    callback = f'''\n            <intent-filter>\n                <action android:name="android.intent.action.VIEW" />\n                <category android:name="android.intent.category.DEFAULT" />\n                <category android:name="android.intent.category.BROWSABLE" />\n                <data\n                    android:scheme="{package}"\n                    android:host="login-callback" />\n            </intent-filter>\n'''
    text = text.replace('        </activity>', callback + '        </activity>', 1)
if 'com.yalantis.ucrop.UCropActivity' not in text:
    cropper = '''\n        <activity\n            android:name="com.yalantis.ucrop.UCropActivity"\n            android:screenOrientation="portrait"\n            android:theme="@style/Theme.AppCompat.Light.NoActionBar" />\n'''
    text = text.replace('    </application>', cropper + '    </application>', 1)
manifest.write_text(text, encoding='utf-8')
PY

cd "$APP"
flutter pub get
flutter analyze

echo "Android project ready with package ID: $PACKAGE"
