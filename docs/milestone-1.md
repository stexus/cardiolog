# Milestone 1 · local implementation and evidence

Implemented 2026-10-05 and committed locally at the user's request. The local browser/native/build deliverables are ready for review. The user will add the remote later, so GitHub execution and publication are pending. Physical-device acceptance remains Milestone 2.

## Review

- Interactive browser companion: **http://10.0.0.242:4173/** (LAN) or **http://127.0.0.1:4173/** (local). The server listens on `0.0.0.0:4173` for the user's headless SSH workflow. This machine's DHCP address changed during implementation; use the current `ifconfig` address if it changes again.
- Matching browser/native screenshots: **http://10.0.0.242:4173/review/** after `python3 scripts/prepare-review.py`.
- Startup: `scripts/serve-preview.sh`, or `python3 -m http.server 4173 --bind 0.0.0.0 --directory mockup`.
- Walkthrough: select **Paused** to inspect mounted-phone controls, **Completed** for aligned graph/interval statistics and Copy Workout, **Ready** to edit/start a session, and **Empty history** for the first-use flow. Appearance and orientation controls are outside the depicted app.

The browser supports template editing/duplication/new templates, equipment selection, simulated sensor choices, disabled Health publishing for samples, pause/resume, next-only/remaining-work setting changes, extra intervals, partial saves, persistent sample history, interval selection, copy field preferences, and sample JSON download. The native shell follows the same hierarchy using SwiftUI forms, sheets, menus, tabs and Swift Charts. Detailed production behavior is intentionally deferred according to the milestone plan.

The reference-app review refined navigation in both versions: **Timers** opens the saved-template list, the top-left back button returns there, and launch restores the last-used template. A selected template shows its own setup and edit/duplicate actions. **Start stays pinned above the tabs** while its details scroll; an existing session changes this to Return to workout. Saved edits, duplicates, and equipment selection survive reload/relaunch. The editor retains its compact existing options; additional cycle groups, alerts, and styling controls are deferred.

The chosen visual direction is **cool blue with native Liquid Glass**. Adaptive blue assets cover light/dark canvas, cards, summary, work, recovery, and warm-up colors. Native navigation and primary actions use system glass; the browser approximates the material with translucent capsules and restrained highlights. Timer data and charts retain quiet surfaces. The review gallery includes light/dark setup and workout comparisons. Browser checks also verified visible Start/tabs at 390×700 and the reduced-transparency fallback (`artifacts/blue-appearance-checks.json`); this is not a full accessibility audit.

## Delivered source

| Location | Contents |
| --- | --- |
| `mockup/` | Self-contained browser review artifact; no backend or runtime npm dependencies |
| `Fixtures/sessions.json` | Schema 1 authoritative examples, shared states, 4×4/bike/partial sessions and HR gap |
| `App/` | SwiftUI Timers/History/Settings, saved-template list and setup, template/equipment forms, workout controls, chart/detail/copy, About |
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
| Browser flow tests | **4 passed**; template edits, scope selection, frozen pause, partial save/reload, all nine states, graph selection/copy fields, mobile layout and landscape action bounds, bike equipment and added interval; Timers/back navigation, remembered edits/selection, canceled drafts, persisted duplication, and pinned Start at 390×700, 844×390, and 900×800. `artifacts/blue-browser-tests.log` |
| LAN browser smoke check | Loaded over plain HTTP at `10.0.0.242`, started and paused a session, no JavaScript errors; secure-context-only UUID use was removed. Clipboard may still require manually copying the visible preview text. |
| Native simulator build | **Passed**, Xcode 26.3 (17C529), iOS SDK 26.2, iPhone 17 Pro / iOS 26.3.1. `artifacts/simulator-build.log` |
| Native UI tests | **4 passed** with the cool-blue palette and native Liquid Glass buttons: no-HR pause/resume, finish/save/relaunch persistence, dark landscape controls and completed-state rendering, Timers/back navigation, remembered selection and creation, pinned Start in portrait/landscape, and banner/back-button separation. `artifacts/iOS-26-blue-glass.xcresult`, `artifacts/blue-native-tests.log`. |
| Unsigned dev IPA | **Passed** archive and package verification, bundle `app.cardiolog.dev`, version 0.1.0, build 1.0.11. `artifacts/dev/` |
| Unsigned release IPA | **Passed** archive and package verification, bundle `app.cardiolog`, version 0.1.0, build 1.0.12. `artifacts/release/` |
| Package rejection tests | **3 passed**: rejects wrong channel, arm64 simulator platform, and missing fixtures. `artifacts/package-rejection-tests.log` |
| Infrastructure checks | Actionlint 1.7.7 passed with verified newer hosted-runner labels configured; shell syntax, plist validation, shared fixture checks, and checksum verification passed. |
| FlareStore feed checks | **13 passed**: exact IPA metadata and permissions, dev/release separation and history, numeric ordering, immutable versions, SHA-protected source updates, authentication failure, upload-before-feed ordering, failed-upload handling, stable retries, and stale dev runs. `artifacts/feed-tests.log`. GitHub calls were mocked; no feed was published. |
| iOS 27 availability | **Unavailable locally**, explicitly reported as unverified. `artifacts/ios-27-availability.log`; separate workflow supplied for a real runtime run. |

Package verification inspects Mach-O platform information, not only arm64 architecture. Each output folder includes the IPA, symbols, checksum file, exact Xcode/SDK/build metadata, and expected entitlement definitions. These local validation artifacts were built before the initial commits: their manifests record `uncommitted` and `sourceDirty: true`. Committing the source does not retroactively change those binaries; subsequent builds record the committed SHA.

Final artifacts:

- `artifacts/dev/CardioLog-Dev-0.1.0-1.0.11-uncommi-unsigned.ipa`
- `artifacts/release/CardioLog-0.1.0-1.0.12-uncommi-unsigned.ipa`

Browser/native portrait comparisons use the same paused 4×4 (13:00 active, 3:00 remaining, entered 6.5 mph / 2%) and completed 35-minute fixture (4/4 work intervals, Work 1 average/max/end 155/167/167). Gap placement and interval settings agree. Native platform chrome and chart axes differ as expected. The landscape layout was tightened after the automated check found the Finish control below the visible area.

## Remaining external and later-milestone work

- User visual review and any requested changes to both representations.
- Add the remote without changing its intended visibility; run workflows and record actual CI/artifact/release links. Static validation and local archives are not successful CI runs.
- Run the automatic FlareStore feed publication after the remote is configured, then test adding its URL and installing in FlareStore. Feed generation and publication sequencing have local regression coverage; actual remote publication/client authentication remain unverified. See [repository feed](builds.md#flarestore-repository-feed).
- Run the iOS 27 lane. Runtime compatibility has not been established locally.
- Confirm proposed bundle IDs and effective entitlements with the user's FlareStore certificate, sign/install both channels, verify standalone launch, updates, and separate data.
- Implement and physically test H10, Health publishing/import, background/locked-phone recording and cues, headphones/silent/Focus behavior, Apple-generated metrics, Bevel and ring credit in the later milestones.
- Replace the common work/recovery editor scaffold and foreground preview session with the generic production builder/recording engine in Milestone 3; complete production analytics/export schema in Milestone 4. Simulated session playback is not interruption-safe real recording.

No remote service, public site, backup service, certificate upload, or phone installation was introduced.
