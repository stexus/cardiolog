#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
cardiolog_os="${1:-26}"
mkdir -p artifacts
xcodebuild -version
xcodebuild -showsdks
xcrun simctl list runtimes
python3 scripts/prepare-fixtures.py --check
swift test --force-resolved-versions
cardiolog_simulator="$(python3 scripts/select-simulator.py "$cardiolog_os")"
xcodebuild test -project CardioLog.xcodeproj -scheme CardioLogDev -configuration Debug \
  -destination "platform=iOS Simulator,id=$cardiolog_simulator" \
  -derivedDataPath artifacts/DerivedData -resultBundlePath "artifacts/iOS-$cardiolog_os-$(date +%Y%m%d-%H%M%S).xcresult" \
  -clonedSourcePackagesDirPath .build/xcode-packages -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO ENABLE_DEBUG_DYLIB=NO
