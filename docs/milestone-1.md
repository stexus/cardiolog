# Milestone 1 · local implementation and evidence

Implemented 2026-10-05 and committed at the user's request. The user subsequently connected the remote; the first GitHub dev build and feed publication passed. Train navigation was refined on 2026-10-09. Physical-device acceptance remains Milestone 2.

## Review

- Interactive browser companion: **http://10.0.0.242:4173/** (LAN) or **http://127.0.0.1:4173/** (local). The server listens on `0.0.0.0:4173` for the user's headless SSH workflow. This machine's DHCP address changed during implementation; use the current `ifconfig` address if it changes again.
- Matching browser/native screenshots: **http://10.0.0.242:4173/review/** after `python3 scripts/prepare-review.py`.
- Startup: `scripts/serve-preview.sh`, or `python3 -m http.server 4173 --bind 0.0.0.0 --directory mockup`.
- Walkthrough: select **Paused** to inspect mounted-phone controls, **Completed** for aligned graph/interval statistics and Copy Workout, **Ready** to edit/start a session, and **Empty history** for the first-use flow. Appearance and orientation controls are outside the depicted app.

The browser supports template editing/duplication/new templates, equipment selection, simulated sensor choices, disabled Health publishing for samples, pause/resume, next-only/remaining-work setting changes, extra intervals, partial saves, persistent sample history, interval selection, copy field preferences, and sample JSON download. The native shell follows the same hierarchy using SwiftUI forms, sheets, menus, tabs and Swift Charts. Detailed production behavior is intentionally deferred according to the milestone plan.

The reference-app review refined navigation in both versions: **Train** opens the selected workout when returning from Settings or History, and launch restores the last-used template. Tapping Train while already selected, or the top-left **Templates** back button, opens the saved-template list. A selected template shows its own setup and edit/duplicate actions. **Start stays pinned above the tabs** while its details scroll; an existing session changes this to Return to workout. Saved edits, duplicates, and equipment selection survive reload/relaunch. The editor retains its compact existing options; additional cycle groups, alerts, and styling controls are deferred.

The chosen visual direction is **cool blue with native Liquid Glass**. Adaptive blue assets cover light/dark canvas, cards, summary, work, recovery, and warm-up colors. Native navigation and primary actions use system glass; the browser approximates the material with translucent capsules and restrained highlights. Timer data and charts retain quiet surfaces. The review gallery includes light/dark setup and workout comparisons. Browser checks also verified visible Start/tabs at 390×700 and the reduced-transparency fallback (`artifacts/blue-appearance-checks.json`); this is not a full accessibility audit.

## Delivered source

| Location | Contents |
| --- | --- |
| `mockup/` | Self-contained browser review artifact; no backend or runtime npm dependencies |
| `Fixtures/sessions.json` | Schema 1 authoritative examples, shared states, 4×4/bike/partial sessions and HR gap |
| `App/` | SwiftUI Train/History/Settings, saved-template list and setup, template/equipment forms, workout controls, chart/detail/copy, About |
| `Sources/CardioLogCore/` | Pure Swift value models, injected clock/sensor interfaces, foreground preview session and bounded preview metrics |
| `Sources/CardioLogPersistence/` | Actor-owned GRDB writer, transactional preview sessions, explicit `v1_preview_sessions` migration |
| `Tests/`, `AppUITests/`, `mockup/tests/` | Core/storage, simulator UI, and browser flow checks |
| `CardioLog.xcodeproj/`, `Config/` | Ordinary project, shared schemes, independent dev/release identities and icons |
| `scripts/`, `.github/workflows/` | Fixture preparation, simulator discovery/validation, archive/package/verification, read-only CI and trusted publication |

GRDB is pinned to 7.11.1 in both resolution files. Preview storage uses `Application Support/CardioLog/Preview/preview.sqlite`; migrations run on every open, without deleting existing sessions. Fixtures seed only once. The store rejects real workouts. Newly simulated sessions do not invent a historical HR trace; the saved session explicitly has no collected HR. No HealthKit API is called.

## Validation performed locally

| Check | Result and evidence |
| --- | --- |
| Swift package tests | **6 passed**; expansion/invalid inputs, delayed refresh/pause/partial finish, future settings scope/final recovery, HR gaps/freshness/copy, migration/reopen/upsert, real-data rejection. `artifacts/swift-tests.log` |
| Browser flow tests | **4 passed**; template edits, scope selection, frozen pause, partial save/reload, all nine states, graph selection/copy fields, mobile layout and landscape action bounds, bike equipment and added interval; Train/back navigation, return to the selected workout from Settings/History, retap to Templates, remembered edits/selection, canceled drafts, persisted duplication, and pinned Start at 390×700, 844×390, and 900×800. `artifacts/train-browser-tests.log` |
| LAN browser smoke check | Loaded over plain HTTP at `10.0.0.242`, started and paused a session, no JavaScript errors; secure-context-only UUID use was removed. Clipboard may still require manually copying the visible preview text. |
| Native simulator build | **Passed**, Xcode 26.3 (17C529), iOS SDK 26.2, iPhone 17 Pro / iOS 26.3.1. `artifacts/simulator-build.log` |
| Native UI tests | **4 passed** with the cool-blue palette and native Liquid Glass buttons: no-HR pause/resume, finish/save/relaunch persistence, dark landscape controls and completed-state rendering, Train/back navigation, return to the selected workout from Settings/History, retap to Templates, remembered selection and creation, pinned Start in portrait/landscape, and banner/back-button separation. `artifacts/iOS-26-train-navigation-retry.xcresult`, `artifacts/train-native-tests-retry.log`. The initial attempt failed before tests due to a missing simulator test-runner socket; restarting the simulator resolved it. |
| Unsigned dev IPA | **Passed** archive and package verification, bundle `app.cardiolog.dev`, version 0.1.0, build 1.0.11. `artifacts/dev/` |
| Unsigned release IPA | **Passed** archive and package verification, bundle `app.cardiolog`, version 0.1.0, build 1.0.12. `artifacts/release/` |
| Package rejection tests | **3 passed**: rejects wrong channel, arm64 simulator platform, and missing fixtures. `artifacts/package-rejection-tests.log` |
| Infrastructure checks | Actionlint 1.7.7 passed with verified newer hosted-runner labels configured; shell syntax, plist validation, shared fixture checks, and checksum verification passed. |
| FlareStore feed checks | **13 passed**: exact IPA metadata and permissions, dev/release separation and history, numeric ordering, immutable versions, SHA-protected source updates, authentication failure, upload-before-feed ordering, failed-upload handling, stable retries, and stale dev runs. `artifacts/feed-tests.log`. These unit tests mock GitHub calls; actual publication is recorded below. |
| iOS 27 availability | **Unavailable locally**, explicitly reported as unverified. `artifacts/ios-27-availability.log`; separate workflow supplied for a real runtime run. |

Package verification inspects Mach-O platform information, not only arm64 architecture. Each output folder includes the IPA, symbols, checksum file, exact Xcode/SDK/build metadata, and expected entitlement definitions. These local validation artifacts were built before the initial commits: their manifests record `uncommitted` and `sourceDirty: true`. Committing the source does not retroactively change those binaries; subsequent builds record the committed SHA.

Final artifacts:

- `artifacts/dev/CardioLog-Dev-0.1.0-1.0.11-uncommi-unsigned.ipa`
- `artifacts/release/CardioLog-0.1.0-1.0.12-uncommi-unsigned.ipa`

Browser/native portrait comparisons use the same paused 4×4 (13:00 active, 3:00 remaining, entered 6.5 mph / 2%) and completed 35-minute fixture (4/4 work intervals, Work 1 average/max/end 155/167/167). Gap placement and interval settings agree. Native platform chrome and chart axes differ as expected. The landscape layout was tightened after the automated check found the Finish control below the visible area.

## Remote validation

Verified against the public GitHub API and live feed, with an update on 2026-10-12:

- [Build unsigned IPA · run 37423241466](https://github.com/stexus/cardiolog/actions/runs/37423241466): **passed** at source `90cb95b`, including baseline validation and dev publication. [Immutable dev-1.1 release](https://github.com/stexus/cardiolog/releases/tag/dev-1.1): version 0.1.0, build 1.1.1.
- [FlareStore feed](https://raw.githubusercontent.com/stexus/cardiolog/sideload/source.json): publicly readable and lists CardioLog Dev. A stable release entry has not yet been published. Feed availability does not establish successful signing or installation.
- [iOS 27 compatibility · run 37423240488](https://github.com/stexus/cardiolog/actions/runs/37423240488): **failed** in `scripts/validate-native.sh 27` with exit code 65. The toolchain/runtime check passed. Public log download returned HTTP 403; the exact test/build failure has not been diagnosed. iOS 27 remains unverified.

October 12 follow-up at source `a56f465`:

- [iOS 27 compatibility · run 38295697782](https://github.com/stexus/cardiolog/actions/runs/38295697782): **passed**, superseding the earlier unverified simulator status.
- [Build unsigned IPA · run 38295697892](https://github.com/stexus/cardiolog/actions/runs/38295697892): **failed** in browser validation; iOS 26 native checks and feed tests passed, but build/publication were skipped. The user-supplied log identified a null Finish-button bounding box during live-view rendering. The fix uses Playwright's retrying full-viewport assertion, preserving the layout requirement, and enables GitHub failure annotations plus retained traces/screenshots.
- Local fix validation: **4 browser tests passed** with the pinned Playwright Chromium, plus **30 repeated passes** of the affected layout test. `.tools/actionlint` passed. Evidence: `artifacts/ci-browser-fix.log`, `artifacts/ci-layout-race-after.log`. Remote validation/publication of this fix is pending.
- The feed remains at version 0.1.0, build 1.1.1; a failed validation intentionally leaves the last published IPA available.

## Remaining external and later-milestone work

- User visual review and any requested changes to both representations.
- Push the browser-test race fix and wait for a successful dev IPA publication; the Train changes are already on remote `main`.
- Add the live feed in FlareStore and test signing/installation. See [repository feed](builds.md#flarestore-repository-feed).
- Keep iOS 26/27 simulator validation passing; physical sensor/Health/background acceptance remains separate.
- Confirm proposed bundle IDs and effective entitlements with the user's FlareStore certificate, sign/install both channels, verify standalone launch, updates, and separate data.
- Implement and physically test H10, Health publishing/import, background/locked-phone recording and cues, headphones/silent/Focus behavior, Apple-generated metrics, Bevel and ring credit in the later milestones.
- Replace the common work/recovery editor scaffold and foreground preview session with the generic production builder/recording engine in Milestone 3; complete production analytics/export schema in Milestone 4. Simulated session playback is not interruption-safe real recording.

No app backend, backup service, certificate upload, or phone installation was introduced. Distribution uses GitHub Releases and the generated feed.
