# CardioLog

Native iPhone interval timer and cardio logger. Milestone 1 provides a browser design companion, matching SwiftUI fixture shell, separate preview persistence, and unsigned dev/release build infrastructure. Real sensor recording and Health integration are later milestones.

## Review in a browser

```sh
python3 -m http.server 4173 --bind 0.0.0.0 --directory mockup
```

Current LAN URL: **http://10.0.0.242:4173/**. Local URL: **http://127.0.0.1:4173/**. Matching native screenshots are served at **http://10.0.0.242:4173/review/** during this review. See [mockup instructions](mockup/README.md) for state selection and editing. No Node installation, backend, certificate, or phone is needed to view it.

## Native app

Open `CardioLog.xcodeproj` in Xcode 26.3 or later. Choose the shared **CardioLogDev** scheme and an iOS 26 simulator. Both schemes use Debug for local Run/Test; Archive uses Dev or Release. All screens identify sample data. Settings includes the same sample-state selector as the browser companion.

```sh
swift test --force-resolved-versions
scripts/validate-native.sh 26
scripts/build-ipa.sh dev
scripts/build-ipa.sh release
```

The package resolution files pin GRDB 7.11.1. An ordinary Xcode project is included; Python regeneration is optional (`scripts/generate-project.py`). Edit `Config/*.xcconfig` for build settings. Dev uses `app.cardiolog.dev` / CardioLog Dev / a DEV icon; Release uses `app.cardiolog` / CardioLog. Neither archive requires signing assets or a debugger.

The app uses `Sources/CardioLogCore` for pure Swift models, injected clock/sensor interfaces, and preview calculations, `Sources/CardioLogPersistence` for an actor-owned GRDB writer and explicit migrations, and `App/` for SwiftUI/platform presentation. The database is `Application Support/CardioLog/Preview/preview.sqlite` inside each channel's sandbox. Real recordings are not implemented and must use a separate store. Copy options use preview-prefixed defaults. HealthKit is not called by the shell.

## Builds and verification

Unsigned IPAs, checksums, manifests, expected entitlements, symbols, logs, and screenshots are under ignored `artifacts/`. [Milestone 1 evidence](docs/milestone-1.md) records checks actually run and remaining external validation.

Milestone 1 is committed locally on `main`; the user will add the remote. No CI run or GitHub release has happened. Once connected, PRs validate, relevant main changes build dev, manual dispatch accepts dev/release/both, and `vMAJOR.MINOR.PATCH` tags publish immutable release assets. Browser-only changes do not trigger an IPA build. The separate iOS 27 workflow fails if its toolchain/runtime is unavailable; a skipped or missing run is not compatibility evidence.

FlareStore currently uses manual IPA import after download. A compatible repository JSON feed and its hosting are still needed for **Add Repository**; pushing the GitHub project alone does not provide one. See [FlareStore repository readiness](docs/builds.md#flarestore-repository-readiness).

See [build procedures](docs/builds.md), [product design](design.md), and [implementation plan](implementation_plan.md). FlareStore signing, physical installation, H10, Health permissions/publication, background cues, and ring credit remain unverified.
