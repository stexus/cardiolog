#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
cardiolog_channel="${1:-dev}"
case "$cardiolog_channel" in
  dev) cardiolog_scheme=CardioLogDev; cardiolog_configuration=Dev; cardiolog_label=CardioLog-Dev ;;
  release) cardiolog_scheme=CardioLog; cardiolog_configuration=Release; cardiolog_label=CardioLog ;;
  *) echo 'Usage: scripts/build-ipa.sh dev|release' >&2; exit 2 ;;
esac
python3 scripts/prepare-fixtures.py --check
cardiolog_version="${CARDIOLOG_VERSION:-$(sed -n 's/^MARKETING_VERSION = //p' Config/Base.xcconfig)}"
if [[ ! "$cardiolog_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo 'Use a numeric major.minor.patch version' >&2; exit 2; fi
mkdir -p artifacts
if [[ -n "${CARDIOLOG_BUILD_NUMBER:-}" ]]; then
  cardiolog_build="$CARDIOLOG_BUILD_NUMBER"
elif [[ -n "${GITHUB_RUN_NUMBER:-}" ]]; then
  cardiolog_ordinal=$((GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT))
  cardiolog_build="$((1 + cardiolog_ordinal / 10000)).$((cardiolog_ordinal / 100 % 100)).$((cardiolog_ordinal % 100))"
else
  cardiolog_counter_file="artifacts/.local-build-counter"
  cardiolog_counter=0
  if [[ -f "$cardiolog_counter_file" ]]; then read -r cardiolog_counter < "$cardiolog_counter_file"; fi
  cardiolog_counter=$((cardiolog_counter + 1))
  printf '%s\n' "$cardiolog_counter" > "$cardiolog_counter_file"
  cardiolog_build="1.$((cardiolog_counter / 100)).$((cardiolog_counter % 100))"
fi
cardiolog_commit="$(git rev-parse --verify HEAD 2>/dev/null || printf uncommitted)"
cardiolog_output="$PWD/artifacts/$cardiolog_channel"
cardiolog_archive="$PWD/artifacts/archives/$cardiolog_channel.xcarchive"
cardiolog_filename="$cardiolog_label-$cardiolog_version-$cardiolog_build-${cardiolog_commit:0:7}-unsigned"
mkdir -p "$cardiolog_output"
xcodebuild -version
xcodebuild -showsdks
xcodebuild archive -project CardioLog.xcodeproj -scheme "$cardiolog_scheme" \
  -configuration "$cardiolog_configuration" -destination 'generic/platform=iOS' \
  -archivePath "$cardiolog_archive" -derivedDataPath "$PWD/artifacts/DerivedData" \
  -clonedSourcePackagesDirPath "$PWD/.build/xcode-packages" -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' \
  ENABLE_DEBUG_DYLIB=NO MARKETING_VERSION="$cardiolog_version" CURRENT_PROJECT_VERSION="$cardiolog_build" CARDIOLOG_COMMIT="$cardiolog_commit" \
  > "$cardiolog_output/archive.log" 2>&1 || { tail -100 "$cardiolog_output/archive.log"; exit 1; }
cardiolog_stage="$(mktemp -d)"
trap 'rm -rf "$cardiolog_stage"' EXIT
mkdir -p "$cardiolog_stage/Payload"
ditto "$cardiolog_archive/Products/Applications/CardioLog.app" "$cardiolog_stage/Payload/CardioLog.app"
(cd "$cardiolog_stage" && ditto -c -k --keepParent Payload "$cardiolog_output/$cardiolog_filename.ipa")
scripts/verify-ipa.sh "$cardiolog_output/$cardiolog_filename.ipa" "$cardiolog_channel" --version "$cardiolog_version" --build "$cardiolog_build"
cp App/CardioLog.entitlements "$cardiolog_output/expected-entitlements.plist"
if [[ -d "$cardiolog_archive/dSYMs" ]]; then ditto -c -k --keepParent "$cardiolog_archive/dSYMs" "$cardiolog_output/$cardiolog_filename-dSYMs.zip"; fi
python3 scripts/write-build-info.py "$cardiolog_output" "$cardiolog_channel" "$cardiolog_version" "$cardiolog_build" "$cardiolog_commit"
(cd "$cardiolog_output" && shasum -a 256 ./*.ipa ./*.zip build-info.json expected-entitlements.plist > SHA256SUMS.txt)
printf 'Unsigned %s artifacts: %s\n' "$cardiolog_channel" "$cardiolog_output"
