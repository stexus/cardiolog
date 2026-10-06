# CardioLog — Implementation plan

Status: Milestone 1 implemented locally; validation evidence and remaining external gates are tracked in [docs/milestone-1.md](docs/milestone-1.md). GitHub execution awaits the remote, which the user will add.

Last updated: 2026-10-05.

## 1. Document ownership and working approach

[design.md](design.md) is the source of truth for app behavior, user experience, data, architecture, and delivery requirements. This document owns execution order, deliverables, build procedures, validation, and outstanding implementation work. Update the design when a product decision changes, and update this plan when the delivery sequence or completion status changes.

The first milestone delivers a browser-viewable mockup **alongside the actual native SwiftUI shell**. Both are developed during the same milestone and use matching screen structure and example data. The user can review and tweak the design in a web browser before any device installation. Native shell and build-pipeline work can proceed while the browser design is being refined; the mockup does not become a prerequisite for starting native work.

Deliver the browser review link and native build evidence together. Building IPAs does not require installing them immediately. Physical signing/install and sensor acceptance begin after the user has had the opportunity to review and refine the browser design. Automated backups and server setup remain out of scope.

## 2. Milestone 1 — Browser mockup, native shell, and IPA pipeline

**Outcome:** a clickable browser preview of the intended app, a matching native shell that builds and runs in the simulator, and dev/release unsigned IPA artifacts ready for later FlareStore testing. No iPhone installation is required to review this milestone.

### 2.1 Browser mockup

Create a small local web prototype under `mockup/`, initially using HTML, CSS, and JavaScript with bundled sample data and no backend. Its job is to make layout, information hierarchy, navigation, and key interactions easy to review and edit. Keep it small enough that evolving the native app does not require maintaining a second production application.

Deliver:

- A phone-sized interactive preview in a desktop browser, with portrait and landscape views. It must also fit a mobile browser viewport.
- Light/dark appearances, readable typography, large workout controls, and the same labels, units, and navigation as the native shell.
- Timers list and selected-template setup, template editing, an active workout, History, workout detail, and Settings. Restore the last-used template on launch; return to the list through the back button or Timers tab. Keep Start visible above the tab bar while setup details scroll. Preview the gym/equipment chooser, Health publishing choice, and configurable Copy Workout flow.
- Simulated interactions for selecting/editing a template, starting, pausing/resuming, changing the next interval's settings and propagation scope, finishing early, viewing a saved session, selecting an interval on a graph, and previewing copied text.
- Deterministic preview states for work, recovery, paused, no HR, disconnected/stale HR, empty history, a completed workout, and a partial workout. A preview-only state selector outside the app frame can jump directly between states.
- A visible sample-data indication. BLE, Apple Health, iOS sharing, audio/background behavior, and permissions are simulations here; they are not reported as tested integrations.
- Editable source and a short `mockup/README.md` explaining how to open it, switch states, and change visual styles and fixtures. User-requested visual tweaks should appear on browser refresh without a new IPA.

Default local viewing contract, to make concrete when these files exist:

```sh
python3 -m http.server 4173 --bind 0.0.0.0 --directory mockup
```

Open `http://127.0.0.1:4173/` locally, or `http://<machine-LAN-IP>:4173/` from the user’s other machine. The all-interface bind is explicitly requested for headless SSH review. Provide that running URL during the milestone handoff and keep the server available for the review session. No GitHub Pages deployment, Unraid service, or public hosting is required. The browser preview remains a design aid; the installed app uses SwiftUI.

### 2.2 Matching native shell

Create the actual Xcode project, shared schemes/configurations, Swift module boundaries, and basic local storage structure. Implement the Timers / History / Settings navigation, saved-template list and remembered selection, workout setup with pinned Start and template-editor scaffolding, active-workout layout, workout detail, and build-information screen in SwiftUI. Use fixture-backed views and injected simulated services until real recording is implemented.

The native shell should reflect the browser's information hierarchy and flow. Complete recording, analytics, and Health integration arrive in later milestones; do not claim those features work merely because their screens exist. Native previews and the simulator should expose the same representative states used in the mockup.

Keep shared versioned JSON fixtures in `Fixtures/`, covering a 4×4 treadmill session, a steady bike session, a partial session, and HR gaps. Bundle or copy these fixtures into the browser preview through a documented preparation step and into native preview/test resources. Prefer one authoritative set of examples over independently hand-entered graphs and numbers. The served mockup must remain self-contained after preparation. Share data and design decisions; no cross-platform production UI or shared JavaScript workout engine is required.

Simulated workouts remain separate from real records and cannot publish to Health. Establish simulator persistence and the intended database migration mechanism without requiring Health authorization.

### 2.3 Build infrastructure

Establish the Git repository/remote, then implement the workflows and scripts in section 7. Create standalone dev and release builds from the same source with separate identities. Run simulator validation, create device archives, verify the unsigned IPAs, and publish the planned artifacts through GitHub Actions once the remote is available.

Browser-only changes should not force an IPA rebuild. Changes to shared fixtures or native UI should trigger the relevant native checks. Keep the browser preview runnable locally independent of GitHub availability.

### 2.4 Review and revision loop

1. Implement corresponding browser screens and native shell views during the same milestone.
2. Present the browser URL, a short walkthrough of the key flows, and native simulator screenshots/build results. Clearly mark simulated or unfinished behaviors.
3. Apply the user's layout, labeling, graph, and interaction feedback to both representations. Record durable product decisions in `design.md`; keep preview-only controls out of the actual app.
4. Check that the two representations still agree before handing off IPAs for device testing. Native controls and OS rendering can differ visually; flow, hierarchy, labels, data, and state semantics should agree.

There is no device-install requirement before this review. The milestone must not be presented as complete with only a browser prototype or only a native shell.

### 2.5 Acceptance criteria

- The documented command serves a working preview at a concrete browser URL, with all listed core screens reachable and representative states selectable.
- The user can review the workout flow and copy/graph presentation without Xcode, a certificate, H10, or a phone installation.
- Light/dark and portrait/landscape layouts are usable; interactive controls operate on the fixture data rather than being decorative buttons.
- The real SwiftUI shell builds and launches in the simulator with matching sample states. At least one fixture-backed session survives relaunch in its separate preview store.
- Both unsigned device IPAs pass package, platform, bundle-ID, version, and resource checks. GitHub workflow runs and artifact links are recorded when the remote is configured; local builds alone are not described as successful CI.
- Browser and native screenshots use matching fixtures and have been checked for obvious layout or flow drift.
- The handoff includes source locations, preview startup instructions/URL, artifact locations, validation results, and specific remaining device checks.

Physical installation, effective signing entitlements, H10 capture, background timing, and ring credit remain explicitly unverified until Milestone 2.

## 3. Milestone 2 — First device installs, recording, and Health integration

After browser review, validate FlareStore signing and installation of both channels using section 7.6. Confirm standalone launch, independent app data, and updates without data loss. Inspect effective entitlements and perform an actual Health authorization/read/write check before treating HealthKit signing as supported.

Implement and verify direct H10 capture to durable local storage, sensor selection, disconnect/reconnect behavior, screen locking, and app switching. Verify that Health-off mode writes nothing from CardioLog. Test publishing a real workout, retrying publication, reading it back, Bevel visibility, and actual Move/Exercise credit. Determine whether native Apple energy estimates are available without compromising the storage/publishing boundary.

Acceptance evidence must distinguish capabilities measured on the user's physical device from simulator or fixture behavior. Save findings about generated metrics, live-session writes, notification/audio behavior, and OS restrictions into the relevant design sections. Local BLE recording must remain useful if Health provisioning is unavailable.

## 4. Milestone 3 — Workout builder and live session

Complete the generic template model, expanded intervals, cue-based timing, beeps, pause/resume, early completion, added intervals, and changes to upcoming settings. Complete gym/equipment profiles and treadmill/bike field layouts. Replace shell simulations with the production timer, persistence, and sensor interfaces.

Verify repeated groups and final-recovery handling, interruption recovery, next-only versus remaining-work changes, and exact separation of pause and recovery. Exercise a full workout with the phone mounted as it will be in the gym. Keep the browser's main flows consistent with any design changes without reproducing native sensor or background code in JavaScript.

## 5. Milestone 4 — History, analysis, and exports

Complete aligned graphs, per-interval statistics, overlays, two-workout comparisons, configurable Copy Workout, manual file exports, and optional Watch-HR import. Replace illustrative graph/summary behavior with calculations over actual locally recorded data.

Verify raw-data preservation, units and timestamps, gaps/coverage, pause mapping, partial intervals, imported-sample deduplication, and repeated Health publication. Exercise individual and all-workout exports. Confirm that copy profiles produce the selected fields and that all these features work with Health publishing disabled. Backup automation and restoration remain deferred.

## 6. Verification matrix

| Area | Evidence |
| --- | --- |
| Browser/native design | Core flows work with the same fixtures; matching screenshots, state labels, light/dark and portrait/landscape layouts; preview available before device installation |
| Timer | Deterministic tests for repeated blocks, pause boundaries, interruptions, added intervals, and early finish |
| Settings propagation | Next-only versus remaining-work behavior; recovery settings remain intact |
| HR and statistics | Gaps, irregular samples, paused periods, source timestamps, unavailable end HR, and repeated imports |
| Persistence | Crash/interruption recovery, bounded buffered loss, schema migration, update preserving history |
| Health | Off means no CardioLog writes; repeated publication is idempotent; no automatic second Watch workout |
| Graphs/export | Selected intervals correspond to the same stored timestamps; exports preserve raw data and units |
| Physical iPhone/H10 | Connection, reconnect, audio/headphones, screen lock, switching apps, a full workout |
| Distribution | Both signed channels launch standalone; correct identities; repeated installs preserve per-channel data |
| OS versions | iOS 26 and iOS 27 UI/timer/storage checks; sensor/Health claims backed by device testing |

Simulator fixtures validate UI and calculations. They do not substitute for Bluetooth, signing, Health synchronization, background-audio, or ring-credit testing. Test these capabilities before building confidence on top of a polished interface.

## 7. Infrastructure implementation details

The following procedures implement the delivery contract in `design.md`. Toolchain availability and external service behavior must be rechecked when executing them.

### 7.1 Required outcome

The repository will have repeatable workflows that produce real-device arm64 **unsigned** dev and release IPAs. The user downloads an IPA on the iPhone, imports it into FlareStore, signs it with their certificate, and installs it. CI does not need the user's certificate, private key, provisioning profile, or Apple-account credentials.

An unsigned IPA is an input to FlareStore, not directly installable by iOS. Final HealthKit entitlements and application identity must be valid after re-signing. Do not treat a successful CI archive as proof of installability.

### 7.2 Workflow contract

Planned infrastructure files (in addition to the browser mockup and fixture files in Milestone 1):

| File | Responsibility |
| --- | --- |
| `.github/workflows/ci.yml` | Reusable validation plus pull-request checks |
| `.github/workflows/build-ipa.yml` | Dev/release selection, validation dependency, unsigned archive/package, artifact publication |
| `.github/workflows/ios-27.yml` | Explicit iOS 27 compatibility lane while its toolchain is managed separately |
| `scripts/build-ipa.sh` | Same channel-aware archive/package entry point locally and in CI |
| `scripts/verify-ipa.sh` | Validate ZIP layout, executable platform/architecture, metadata, required resources, and expected channel |
| `Config/*.xcconfig` | Deployment target, bundle IDs, version/build settings, channel flags |

Triggers:

- Pull requests: simulator/core tests and compile validation; no release publication.
- Push to `main`: validate and produce the dev IPA when app/build inputs change; docs-only and browser-mockup-only changes do not need an IPA. Shared fixture or native design changes run the relevant native checks.
- Manual `workflow_dispatch`: choose `dev`, `release`, or `both`; use GitHub's branch/ref selector.
- A version tag such as `v0.1.0`: validate and publish the release IPA for that tagged commit.

Require validation to finish before publishing installable artifacts. Fork PRs get read-only checks. Grant `contents: write` only to the trusted release-publication job; normal jobs use read permissions. Cancel superseded dev runs and serialize publication of the latest-dev pointer so an older run cannot replace a newer build. Release tags/assets are immutable.

Pin external actions to reviewed commit SHAs and lock package versions. Cache dependency downloads using toolchain and resolution-file keys. Do not cache certificates, user data, or a mutable build directory without appropriate invalidation.

### 7.3 Runner and toolchain

Use a GitHub-hosted macOS runner for Xcode compilation. The Unraid server is not part of the iOS build path.

The local environment inspected on 2026-10-05 had Xcode 26.3 (17C529), iOS SDK 26.2, and an iOS 26.3 simulator runtime. Proposed bootstrap CI baseline: `macos-26` with `/Applications/Xcode_26.3.app/Contents/Developer`, explicitly selected rather than whatever `macos-latest` happens to provide. The image inventory consulted at that time listed that Xcode installation. Recheck availability when implementing and fail clearly if a pinned toolchain is missing. [Runner image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md).

Discover an appropriate installed iOS 26 simulator by runtime/device identifiers rather than hard-coding a runner-specific simulator UUID. Log `xcodebuild -version`, SDK versions, simulator runtime, and build settings relevant to the artifact.

The runner documentation consulted on 2026-10-05 listed a separate `xcode-27` public-preview runner for iOS 27; recheck its availability and status before implementing this lane. Keep this lane explicit and record its exact toolchain/runtime. A preview-infrastructure failure can be reported separately during bootstrap, but passing the supported runtime tests is required before claiming iOS 27 compatibility. Simulator success does not certify BLE or ring behavior. Do not silently skip unavailable iOS 27 tests and call the product verified. [GitHub runner labels](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job).

### 7.4 Build and package

The packaging script should:

1. Resolve the channel, scheme, configuration, bundle ID, semantic version, and unique build number.
2. Resolve locked dependencies and build/archive for `generic/platform=iOS`, never the simulator SDK.
3. Disable signing for CI archive creation; preserve the source entitlement definitions for later signing validation.
4. Use the archived device app, including all required embedded frameworks/resources, as the packaging source.
5. Stage the app under `Payload/<Product>.app` and ZIP that directory into an IPA using a tool that preserves bundle contents and symlinks.
6. Verify the executable is an iOS-device arm64 binary, not merely an arm64 simulator binary; inspect Mach-O platform information as well as architecture.
7. Verify bundle ID, display name, deployment target 26.0, version/build number, permission descriptions, background modes, and absence of debugger-only dependencies.
8. Publish the IPA, checksum, build metadata, expected entitlement manifest, and debugging symbols where generated.

Intended archive command shape, to be implemented and tested with the real project:

```sh
xcodebuild archive \
  -project CardioLog.xcodeproj \
  -scheme "$cardiolog_scheme" \
  -configuration "$cardiolog_configuration" \
  -destination 'generic/platform=iOS' \
  -archivePath "$cardiolog_archive_path" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  DEVELOPMENT_TEAM='' \
  ENABLE_DEBUG_DYLIB=NO
```

Unsigned ZIP packaging is the intended FlareStore route. Do not assume a conventional signed `-exportArchive` flow works without provisioning. Validate the chosen archive/package process with the first real device installation.

### 7.5 Download experience

Produce clearly named files, for example:

- `CardioLog-Dev-0.1.0-123.1-abc1234-unsigned.ipa`
- `CardioLog-0.1.0-124.1-def5678-unsigned.ipa`
- `SHA256SUMS.txt`
- `build-info.json`
- `expected-entitlements.plist`

Use a valid monotonically increasing `CFBundleVersion` derived from workflow run number and attempt, with a deliberate versioning policy if workflows are renamed/recreated. Semantic version comes from the release tag or the checked-in development version. The manifest includes channel, bundle ID, commit, Xcode/SDK, minimum OS, build number, and unsigned status.

Actions artifacts provide a fallback, but GitHub Release assets should provide convenient direct IPA downloads. Maintain a clearly labeled latest-dev prerelease after successful builds, with immutable versioned release downloads for stable builds. Exclude the dev prerelease from GitHub's stable latest-release designation. Save commit/build information alongside every published IPA. [GitHub workflow artifacts](https://docs.github.com/en/actions/tutorials/store-and-share-data).

Keep repository visibility unchanged when implementing. Private release assets require GitHub authentication; the supported initial flow is download through the authenticated browser, then import from Files into FlareStore. Do not assume FlareStore can fetch private GitHub URLs with the user's browser session.

Generate an AltStore-compatible FlareStore source automatically after successful IPA publication. Host `source.json` on the `sideload` branch at `https://raw.githubusercontent.com/OWNER/REPO/sideload/source.json`; no Pages deployment is required. Dev and release have separate app entries, populated only after their actual artifacts exist, with exact versions/builds, minimum OS, sizes, permissions, and immutable download links. Preserve version history and the other channel when updating. Store each release's app-entry metadata with its immutable assets so a failed feed update can be retried without replacing an IPA. Serialize feed writes and use the GitHub file SHA to protect concurrent updates. Keep repository visibility unchanged and never embed a GitHub token in the feed; private repositories still require client-compatible authentication or manual import. [FlareStore repository support](https://flarestore.app/guide/ios/).

### 7.6 Signing and install checklist

1. Download the desired channel's IPA on the iPhone.
2. Import it into FlareStore and select the user's certificate/profile.
3. Preserve the channel bundle ID and required HealthKit capabilities during signing.
4. Install the signed app and grant Bluetooth/Health/notification permissions as needed.
5. Confirm the app opens without Xcode, a debugger, or a dev server.
6. Record a short session, terminate/relaunch, and verify local persistence.
7. Install a newer IPA over that channel and verify history survives.
8. Check that Dev and Release coexist with separate data and preferences.

HealthKit signing is an early gate: check both the provisioning capabilities and the signed app's effective entitlements. Verify behavior through an actual authorization/read/write cycle. A sidecar entitlement file alone does not grant the app a capability. If re-signing cannot preserve the required capabilities, record the precise signing limitation; BLE/local recording must still function.

## 8. Handoff and status tracking

Current state: the browser companion, SwiftUI project, shared fixtures, GRDB preview store, tests, unsigned packaging scripts, and GitHub workflows exist. Git is initialized on `main`; no remote was added, as requested by the user. See [Milestone 1 evidence](docs/milestone-1.md) for actual local results. CI and release links must be added after the remote is configured.

Established during Milestone 1:

- Local Git repository on `main`; remote/visibility remain the user’s later setup.
- Proposed `app.cardiolog.dev` / `app.cardiolog` identities in explicit configurations; final provisioning remains unverified.
- Xcode 26.3, iOS 26.3 simulator, GRDB 7.11.1 lockfiles, and pinned CI action commits. iOS 27 is not installed locally.
- Fixture schema 1 in `Fixtures/`; self-contained browser/native copies. LAN preview uses `--bind 0.0.0.0` for the user’s headless SSH workflow.

For each milestone, record completed work, reproducible commands, artifact/preview links, validation results, and remaining external/device dependencies. Do not mark an install or integration verified based on a mockup, simulator, or unsigned archive.

Next: review the browser/native screenshots, apply requested visual feedback to both, then connect the remote and record real workflow/artifact links. Device signing and integration tests follow in Milestone 2 after browser review. No backup or home-server work is needed.
