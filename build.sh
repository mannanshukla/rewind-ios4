#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
SDK="${IPOD_SDK:-${HOME}/ios4sdk/iPhoneOS4.3.sdk}"
rm -rf build/Payload
rm -f build/Rewind.ipa
mkdir -p build/Payload/Rewind.app
clang -target armv7-apple-ios4.3 -isysroot "$SDK" -fobjc-runtime=ios-4.3 -fno-objc-arc -marm -O2 -Wall -Wno-deprecated-declarations src/main.m -o build/Payload/Rewind.app/Rewind -framework UIKit -framework Foundation -framework MediaPlayer -framework QuartzCore -framework CoreGraphics -framework AudioToolbox -lobjc
cp res/Click*.wav build/Payload/Rewind.app/
cp res/Info.plist res/Icon.png res/Icon@2x.png res/Chicago.ttf build/Payload/Rewind.app/
ldid -S build/Payload/Rewind.app/Rewind
(cd build && zip -qr Rewind.ipa Payload)
echo 'Built build/Rewind.ipa'
