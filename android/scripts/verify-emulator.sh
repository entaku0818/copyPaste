#!/bin/bash
# Destructive only to the two disposable prototype apps on an emulator.
set -euo pipefail
cd "$(dirname "$0")/.."
serial="${1:?Usage: verify-emulator.sh emulator-5554}"
if [[ "$(adb -s "$serial" shell getprop ro.kernel.qemu | tr -d '\r')" != 1 ]]; then
  echo 'Refusing to change a physical device IME.' >&2
  exit 1
fi
./gradlew :app:assembleDebug :app:lintDebug :app:testDebugUnitTest :fixture:assembleDebug :fixture:assembleDebugAndroidTest :fixture:lintDebug
adb -s "$serial" install -r app/build/outputs/apk/debug/app-debug.apk
adb -s "$serial" install -r fixture/build/outputs/apk/debug/fixture-debug.apk
adb -s "$serial" install -r fixture/build/outputs/apk/androidTest/debug/fixture-debug-androidTest.apk
original_ime="$(adb -s "$serial" shell settings get secure default_input_method | tr -d '\r')"
original_hardware="$(adb -s "$serial" shell settings get secure show_ime_with_hard_keyboard | tr -d '\r')"
restore() {
  adb -s "$serial" shell ime set "$original_ime" >/dev/null
  if [[ "$original_hardware" == null ]]; then
    adb -s "$serial" shell settings delete secure show_ime_with_hard_keyboard >/dev/null
  else
    adb -s "$serial" shell settings put secure show_ime_with_hard_keyboard "$original_hardware" >/dev/null
  fi
}
trap restore EXIT
adb -s "$serial" shell settings put secure show_ime_with_hard_keyboard 1
adb -s "$serial" shell pm clear com.clipkit.prototype
result="$(adb -s "$serial" shell am instrument -w com.clipkit.fixture.test/com.clipkit.fixture.PrototypeRunner)"
printf '%s\n' "$result"
[[ "$result" == *'ALL INTEGRATION CHECKS PASSED'* && "$result" != *'FAIL:'* ]]
