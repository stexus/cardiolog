# CardioLog — Product and infrastructure design

Status: app design baseline. Visual details can evolve through browser review; requirements and architectural decisions are maintained here.

Last updated: 2026-10-05.

This document defines what CardioLog does, how its interface and data behave, and the architecture and delivery constraints that support it. It is the durable product and technical design, independent of implementation progress. Milestones, procedural build instructions, validation tasks, and implementation status live in [implementation_plan.md](implementation_plan.md).

## 1. Purpose and priorities

CardioLog is a native iPhone interval timer and cardio logger, primarily for treadmill workouts, with indoor cycling support. It records workout structure, equipment settings, and heart rate on an aligned timeline. Data belongs to CardioLog's own local store and is easy to inspect and export for ChatGPT or other AI agents.

Priorities, in order:

1. Reliable timing and recording during an actual workout.
2. A very native iPhone experience with large, clear controls.
3. Complete local ownership of recorded data, independent of Apple Health.
4. Useful interval graphs, summaries, and portable exports.
5. Convenient device builds through GitHub Actions and FlareStore.
6. A fast development loop, provided it does not compromise the preceding priorities.

Bevel remains the user's broader training-analysis tool. CardioLog supplies workout and HR data through optional Apple Health publishing; its own exports retain additional interval and equipment detail.

## 2. Platforms and constraints

| Item | Decision |
| --- | --- |
| Product name | **CardioLog**, with capital C and L |
| Primary device | iPhone 15 Pro Max, currently running iOS 26 |
| Minimum deployment target | iOS 26.0 |
| Compatibility requirement | iOS 26 and iOS 27; explicitly validate both |
| Primary HR sensor | Polar H10, connected directly to the iPhone |
| Workout display | iPhone resting on the treadmill |
| Existing watch | Apple Watch Series 4; no upgrade required by this design |
| Watch integration | No custom watchOS app in the first version |
| Installation | Download an unsigned IPA, sign and install using the user's FlareStore certificate |
| Network dependence | Recording, timing, history, graphs, and copying work offline |
| Home server | Unraid with Syncthing and Tailscale; no server dependency in this version |

The user selected direct H10 recording after reviewing FlareStore's stated Watch limitations. When the H10 is unavailable, Apple's Watch Workout app can record the Health workout; CardioLog runs the timer and can import available HR afterward. A live Watch-to-CardioLog HR bridge is not part of this design.

FlareStore documents IPA import/sign/install and lists HealthKit among its certificate capabilities. Actual provisioning and HealthKit operation must be verified with the user's signed build; the vendor's advertised support is not a completed device test. [FlareStore installation guide](https://flarestore.app/guide/ios/), [certificate FAQ](https://flarestore.app/faq/).

## 3. Scope

### Included in the first version

- A configurable workout builder with saved templates.
- Timed warm-up, work, recovery, and cooldown phases, including repeated groups.
- Start, pause, resume, finish early, and add an interval.
- Beeps for transitions and an optional short countdown; no spoken announcements.
- One set of equipment settings per interval, with editing of upcoming intervals.
- Gym and equipment profiles.
- Direct H10 connection, recording, disconnect indication, and reconnection.
- Local workout history that works without Health permissions.
- Optional Health publishing and optional import of Watch-recorded HR.
- Basic HR-zone coloring with editable configuration.
- HR graphs aligned with intervals and equipment settings.
- Interval overlays and comparison of two selected workouts as the initial comparison scope.
- Configurable copying of one workout for AI use.
- Manual JSON/CSV export of individual workouts and all recorded workouts.
- Separate dev and release IPA channels, produced by GitHub Actions.

### Deferred or excluded

- Automated backups, backup scheduling, server upload, and a full backup/restore product flow.
- Unraid services, WebDAV, Syncthing integration, Git-based data backup, and iCloud sync.
- A custom Apple Watch app or guaranteed live Watch HR on the iPhone.
- Automatic treadmill/bike telemetry or equipment control.
- Changes to historical intervals or timestamped speed changes within an interval.
- Distance-triggered interval completion; initial phases are time-based.
- Adaptive coaching, training prescriptions, or a custom calorie-estimation model.
- Multi-workout AI copying, built-in AI chat, and longitudinal coaching dashboards.
- Raw ECG capture or an HRV-analysis product.
- Downloaded executable code or a custom remote-code-update framework.

Deferring backups does not remove data portability: manual workout exports remain in scope. Full archives containing every setting and an import/restore workflow are future work. No production storage is placed in a directory managed by a file-sync tool.

## 4. Workout model and behavior

### 4.1 Configurable templates

A template contains an ordered sequence of timed steps and repeat groups. A step has a role, label, duration, activity/equipment context, and optional equipment settings. A repeat group contains steps and a repetition count. One level of repeat groups is sufficient initially; groups can be placed sequentially to represent more complex sessions.

Controls include:

- Optional warm-up duration.
- Work duration and recovery duration.
- Repetition count.
- Optional recovery after the last repetition.
- Optional cooldown duration.
- Per-step settings, with shared defaults for repeated work and recovery steps.
- Add, remove, reorder, save, and duplicate template elements.

The user's common workouts are examples, not hard-coded models: Norwegian 4×4, long steady cardio, and threshold sessions. Norwegian 4×4 can ship as an editable preset with four 4-minute efforts and 3-minute recoveries between efforts. Warm-up, final recovery, and cooldown remain configurable. A single long work step represents a steady session.

At workout start, snapshot the template and expand its repetitions into concrete interval instances. Editing a template later must not alter past workouts.

### 4.2 Timing and transitions

- An interval starts **at the cue**. There is no separate treadmill-acceleration confirmation.
- Each phase advances automatically when its active duration expires.
- The timer tracks workout active time, phase active time, wall-clock timestamps, and pauses separately.
- Pause freezes workout and phase active timers. It cancels pending phase cues until resume.
- Keep a sensor connection available during pause if useful, but omit paused HR from the recorded workout and its statistics by default.
- A planned recovery is an active timed phase; it is distinct from pausing. Record recovery HR normally.
- Finish early saves a partial session and the actual duration of the current phase.
- Add interval inserts another work/recovery repetition before cooldown. Show the resulting timeline and duration; preserve an explicit final-recovery rule.
- Zero-length optional phases are omitted. Reject negative durations, invalid counts, and an empty workout.

Use a monotonic elapsed-time source while running. UI refresh timers render state; they do not advance the authoritative workout by subtracting one second per callback. Maintain wall-clock anchors for Health import and export. Persist phase transitions, pauses, adjustments to future steps, and recording checkpoints.

After app interruption, reconstruct the timeline from persisted state. If the app was terminated and precise continuity cannot be established, mark the interruption and retain collected data instead of presenting an uninterrupted recording. Do not replay a backlog of obsolete beeps on return.

### 4.3 One setting per interval

Each interval has one entered speed/incline pair for a treadmill, or one entered resistance/cadence pair for a bike.

- During recovery, make editing the next work interval easy.
- Apply a change to the remaining **work intervals** by default, with an option to affect only the next work interval.
- Changing work settings does not overwrite recovery, warm-up, or cooldown settings.
- Freeze an interval's entered settings when it starts.
- Do not add retrospective editing, sub-interval events, or a second-by-second equipment editor in the first version.
- These are user-entered settings. The app must not describe them as machine-measured telemetry or claim that a treadmill reached a setting at the cue.

If the user changes the actual machine during an interval without logging it, the stored setting remains the entered value. This deliberately simple model trades equipment precision for a usable workout interface. A note can capture exceptions.

## 5. Gyms and equipment

A gym has a stable ID, name, and optional notes. An equipment profile belongs to a gym and has a type, optional model/nickname, units, input increments, and optional useful limits/defaults.

| Equipment | Per-interval fields |
| --- | --- |
| Treadmill | Speed, defaulting to mph; incline in percent |
| Indoor bike | Resistance level and cadence in rpm |

Bike resistance is specific to that machine/profile. Do not treat a resistance level as a standardized workload across bikes. Allow an equipment model to be unknown; selecting a gym does not require identifying an individual numbered machine.

Remember the most recently selected gym and equipment, and make changing them explicit before starting. Snapshot names, equipment type, and units into each workout so changing the current gym or renaming a profile does not rewrite history. Profiles used by history can be archived.

## 6. Recording and HR data

### 6.1 Direct H10 capture

Use Apple's Core Bluetooth framework to read the standard Bluetooth Heart Rate Service. Scan, let the user select their H10, remember that sensor, and reconnect to the selected device. Do not automatically choose another person's nearby sensor in a gym.

Polar supports third-party applications and provides an iOS SDK. Standard HR capture can start with Core Bluetooth; add Polar's SDK only if an implemented feature requires its device-specific functions. Polar Flow remains useful for sensor settings and firmware. [H10 manual](https://support.polar.com/e_manuals/h10-heart-rate-sensor/polar-h10-user-manual-english/getting-started.htm), [Polar SDK](https://github.com/polarofficial/polar-ble-sdk).

Persist delivered HR readings with their timestamps, source, and quality/context information. Standard BLE HR notifications do not supply a universal workout timestamp: record phone receipt time and an elapsed-time anchor, and identify that timestamp basis in exports. Retain true source timestamps when importing from HealthKit. Do not imply that receipt time is a precisely measured beat time.

Show connecting, connected, stale, disconnected, and reconnecting states. A live HR value must visibly become stale when updates stop. Recording gaps remain gaps; they are not zero-bpm readings. The interval timer continues through HR loss.

H10 can support two simultaneous Bluetooth receiver devices when configured, but CardioLog's normal H10 workflow needs only the iPhone. Existing Watch or gym-equipment connections may affect connection availability. [Polar dual-connection guidance](https://support.polar.com/en/support/can_i_pair_h10_with_several_devices).

### 6.2 No H10 available

The user can record an Indoor Run or other appropriate workout with Apple's Watch Workout app while CardioLog records its own interval/equipment timeline. Keep CardioLog's Health publishing off for that session.

After Watch data becomes available in Apple Health, with read authorization:

1. Find likely workouts using activity type and time overlap.
2. Let the user select the match if several are plausible.
3. Import available HR into the existing local CardioLog workout, retaining provenance and external sample IDs.
4. Align by real timestamps and CardioLog's pause/phase boundaries. Do not stretch a trace to make start times or durations match.
5. Re-import without duplicating samples or creating another local workout.

Handle condensed HealthKit quantity samples through the appropriate series queries where needed. Do not promise live Watch HR, immediate Health synchronization, or complete HR coverage. Imported samples during CardioLog pauses are excluded from the local active timeline.

## 7. Storage and Apple Health

### 7.1 Local data is authoritative

Every workout is recorded and saved locally first, even if Health access is denied, unavailable, or disabled. Graphs, copying, and file exports query local data. HealthKit is an integration, never the only persistence layer.

Recommended storage: SQLite through GRDB, accessed through a serialized repository/writer with transactional updates and explicit schema migrations. This supports raw HR time series, queries, and portable exports. Pin the dependency through Swift Package Manager and commit the resolution file. [GRDB](https://github.com/groue/GRDB.swift).

Write incoming samples in small durable batches and flush on transitions and normal completion. Target at most a few seconds of buffered data during active collection. File protection must permit the intended locked-phone recording after first unlock; test this on device. Do not depend on the view hierarchy or an in-memory array to retain a workout.

Suggested logical records:

| Record | Essential contents |
| --- | --- |
| Gym / equipment | Stable IDs, type, names, units, field defaults |
| Template | Versioned ordered steps and repeat groups |
| Workout | UUID, template snapshot, activity, gym/equipment snapshots, start/end, status, notes |
| Interval | UUID, role/repetition, planned duration, actual boundaries, one set of entered settings |
| Pause / session event | Timestamps and events needed to reconstruct elapsed time |
| HR sample | Workout ID, bpm, timestamp/basis, source, external identity where available |
| Data gap | Known disconnection/interruption boundaries and reason |
| Zone configuration | Max-HR value, provenance, thresholds, version |
| Health publication | Workout ID, publication identity/version, status, external workout ID |
| Copy preferences | Selected fields, saved named profiles, formatting version |

Store explicit units; use consistent canonical values for calculations and preserve entered units for presentation. Missing readings/settings are null, never invented zeroes. Derived metrics are reproducible from original observations and record their calculation version.

### 7.2 Optional publishing

Provide a remembered Health publishing preference, a clear per-workout choice, and a later explicit Publish to Apple Health action for unpublished workouts. Dev builds start with publishing off. During release onboarding, the user chooses whether CardioLog or the Watch normally saves the Health workout.

| Session | Local CardioLog data | Health writer |
| --- | --- | --- |
| H10 with CardioLog publishing enabled | Direct HR plus intervals/settings | CardioLog |
| H10 with publishing disabled | Direct HR plus intervals/settings | No CardioLog writes |
| Watch records without H10 | Intervals/settings plus later imported HR | Apple's Watch Workout app |

The presence or loss of an H10 never silently changes the publishing preference. Disabling publishing does not remove local history. Turning it back on does not bulk-publish old sessions. Already-published Health data is not automatically deleted when a preference changes.

Prevent duplicate exports of CardioLog's own workout using a persistent publication ledger and stable HealthKit sync identifiers/versions. Recover safely if Health saving succeeds but the local completion update is interrupted. Retries must reconcile the existing publication before creating another. HealthKit sync metadata is an aid for app-owned records, not cross-app deduplication. [Sync identifier](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier), [sync version](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncversion).

An overlapping Watch workout can prompt the user to keep the session local. An empty Health query is not proof that no Watch workout exists: synchronization may be delayed and read authorization may be unavailable. Never automatically delete or replace a workout created by another app.

### 7.3 Native workout APIs, calories, and rings

Use `HKWorkoutBuilder` for publication, with appropriate activity type, elapsed/active times, events, and associated HR samples. Publish actual available data. Preserve the distinction between measured HR, user-entered equipment settings, and any estimated distance or energy.

iOS 26 supplies native iPhone workout-session APIs. Availability of system-generated metrics for a stationary iPhone receiving H10 HR during an indoor treadmill or bike session is device-dependent behavior to validate; it is not an assumed product capability. Use Apple-generated energy estimates when available; do not implement a custom calorie model for the first version. Merely publishing HR does not establish a calorie value. [Apple's iPhone workout APIs](https://developer.apple.com/videos/play/wwdc2025/322/).

Apple documents Move credit from associated active-energy samples, Exercise credit based on iOS workout duration, and Stand credit for overlapped clock hours, subject to correct workout saving and required data. Verify actual ring behavior on the user's device; support for publishing a workout is not proof of Move credit. An absent calorie estimate must stay absent. [Apple's workout/ring documentation](https://developer.apple.com/documentation/healthkit/hkworkout).

**Important integration constraint:** a live HealthKit session may write generated samples before the final workout is saved. In local-only mode, do not start a Health-writing session merely to keep the app alive or obtain calories. Direct BLE capture must remain usable independently. Any native-session integration must honor this boundary. If live Health collection is used in publishing-enabled mode, explain that mode before starting; stopping publication can prevent later writes but cannot undo existing samples automatically. Later publication of a local-only session must not promise retroactive Apple calorie generation.

### 7.4 Bevel

When CardioLog is the publisher, include the workout and its HR samples so Bevel can read them from Apple Health. Bevel documents missing HR as a cause of missing cardio-load data. Do not assume it imports CardioLog's custom interval/equipment fields or custom JSON files. Those remain available through CardioLog's exports. [Bevel device integration](https://help.bevel.health/en/articles/10400449), [Bevel fitness troubleshooting](https://help.bevel.health/en/articles/11680321).

## 8. User experience

Use SwiftUI navigation, sheets, forms, pickers, system typography, SF Symbols, native sharing, accessibility labels, and Dynamic Type. Prefer system behavior over custom imitations. Give the live screen high contrast and large touch targets without hiding meaning in color alone.

### 8.1 Navigation and screen hierarchy

The navigation has three tabs: **Timers**, **History**, and **Settings**. Timers contains a saved-template list and a separate setup screen for each template. On launch, open the last-used template directly (the last selected, saved, or started template); the first bundled template is the initial default. The upper-left back button and an explicit tap on the Timers tab, including tapping the already-selected tab, return to the list. Completed-workout details and comparisons belong to History. The active workout is a dedicated presentation that prioritizes session controls. Returning to another screen must not end recording, and an in-progress session must remain easy to reopen.

Screen responsibilities:

| Area | Contents |
| --- | --- |
| Timers | Saved-template list and create action; selected-template setup with equipment, HR, Health, edit/duplicate and Start |
| Active workout | Large phase countdown, phase/repetition, live HR, entered settings, next phase, pause/finish/add controls |
| History | Completed and partial sessions; filters by template/activity/gym/equipment |
| Workout detail | Summary, interval table, aligned graphs, overlay, notes, Copy, Export, Health publication status |
| Settings | Equipment profiles, zones, copy profiles, Health preferences, app/build information |

### 8.2 Core flows

**Prepare a workout.** Timers presents saved templates with names, activity, and duration, plus a create action. Selecting a template opens a setup summary showing the phase sequence, repetition count, total planned active duration, gym/equipment, and entered work/recovery settings. This screen contains only actions relating to the selected template: edit, duplicate, setup choices, and start. Browse other templates through the parent list instead of an inline Change template action. Preserve saved edits, duplicates, equipment choice, and the selected template across relaunches; canceling an editor must leave the saved template unchanged. HR connection and Health publishing are separate controls with visible current states. Starting without HR is allowed. The user can understand whether the session will publish to Health before starting.

Keep a large Start button pinned above the tab bar while the setup details scroll, in portrait and landscape. Starting the familiar template should never require scrolling through its editor or phase list. If a workout is already active, this action returns to that workout instead of replacing it.

**Edit a template.** Show an ordered list of steps and repeat groups with plain labels and durations. Repeated work/recovery pairs remain understandable as a group, with an explicit repetition count and final-recovery setting. Editing a step opens a focused native form for role, duration, and equipment settings. Keep warm-up and cooldown optional. Update the total duration and sequence preview as the user changes the template.

For Milestone 1, retain the compact editor: name, warm-up/cooldown, work/recovery durations, repetitions, final recovery, and entered equipment settings. The reference app's extra cycle groups, cycle rests, halfway alerts, colors, and icons are not additions to this milestone. Keep the already-planned short pre-start countdown in the later recording/cue work.

**Run a workout.** The largest element is the current phase countdown. Immediately nearby, show the phase name and work repetition, such as “Work · 2 of 4.” Live HR and its connection/freshness state remain visible, followed by the current entered equipment settings and what comes next. Active elapsed time and total progress are secondary. Pause/Resume is prominent; Finish is distinct and requests confirmation before ending an unfinished session. Add Interval and Edit Next remain available without competing with the countdown.

**Adjust the next work interval.** Open a compact sheet with speed/incline or resistance/cadence and the scope choice “Remaining work intervals” or “Next work interval only.” Show which intervals will change before applying it. During recovery, this action should be easy to reach. Current and completed interval settings remain frozen. If no future work interval remains, explain that state and expose Add Interval instead of presenting an ineffective editor.

**Finish and review.** Saving opens workout detail with completion status, active duration, completed work count, and an interval-aligned HR graph. The interval table and selected-interval statistics connect directly to that graph. Copy Workout and Export are easy to find. Health publication status and an eligible Publish action are independent of the successful local save. Editing a note does not change recorded intervals.

**Copy for AI.** Present the saved copy profile, field selections, and a readable text preview before copying. Defaults include interval counts/settings and average, maximum, and end HR per work interval. Missing data remains explicit in the preview. Copy-profile changes can be saved for the next workout.

### 8.3 Visual and interaction rules

Use system typography and semantic foreground/background colors, with monospaced digits for changing timers and numerical readings. Light and dark appearances should preserve the same hierarchy. Phase and HR-zone colors supplement text; disconnects, pauses, and partial completion also have explicit labels. Keep styling values centralized so visual refinements can be applied consistently. Accent colors, spacing, and chart treatment are initial design choices to refine through the browser companion.

The selected aesthetic is **cool blue with Liquid Glass**: icy backgrounds, clear-looking floating controls, vivid blue primary actions, and quiet content surfaces. Use native Liquid Glass for system navigation, tab bars, menus, and prominent actions such as Start and Pause/Resume. Keep timer digits, charts, settings, and interval rows on stable, readable surfaces; avoid turning every card into glass. Native components provide the actual adaptive material and interaction. The browser approximates it using translucent capsules, blur, edge highlights, and restrained shadows. Prefer the regular native material for legibility; “clear-looking” describes the aesthetic rather than requiring the `.clear` API variant. [Apple material guidance](https://developer.apple.com/design/human-interface-guidelines/materials), [prominent glass buttons](https://developer.apple.com/documentation/swiftui/glassprominentbuttonstyle).

| Role | Light | Dark |
| --- | --- | --- |
| Canvas | Ice `#F0F5FD` | Midnight blue `#0B1423` |
| Content cards | White `#FFFFFF` | Blue slate `#142239` |
| Primary accent / work phase | Vivid blue `#1761D8` | Pale blue `#91BDFF` |
| Summary surface | Frost blue `#E1EDFF` | Deep blue `#1B3558` |
| Recovery | Steel blue `#779CC7` | Steel blue `#668DBB` |
| Warm-up / cooldown | Blue gray `#B9C9DF` | Blue gray `#425775` |

Use adaptive, high-contrast foregrounds on blue controls. Reserve warm colors for meaning: red for HR and destructive actions, amber for warnings. Keep the typography and layout calm; the workout countdown remains the dominant element. Respect Reduce Transparency, Increase Contrast, and Reduce Motion through native controls and browser media-query fallbacks. Light/dark is the appearance choice; multiple decorative theme presets are not needed for this direction.

Use large tap areas for workout controls, normally at least 44 × 44 points in the native app. Increased text size should reflow secondary information rather than truncate the countdown, phase, or essential actions. Charts expose textual interval statistics as an accessible alternative to visual inspection.

Portrait is the primary layout; provide a useful landscape workout layout for a mounted phone. Keep the screen awake during an active foreground workout by default and restore normal idle behavior afterward. Offer a setting to allow normal screen locking.

### 8.4 Session and integration states

| State | Visible behavior |
| --- | --- |
| Ready with H10 | Selected sensor and fresh HR appear separately from the Health publishing choice |
| Ready without HR | Starting remains available; explain that the timer/settings will still be recorded |
| Work or recovery | Distinct phase label, countdown, repetition context, current settings, and upcoming phase |
| Paused | Explicit paused state, frozen clocks, prominent Resume; no apparently current recorded HR |
| Stale/disconnected HR | Visible freshness/connection message and graph gap; timing continues |
| Health disabled or unavailable | Local recording and saving remain available; no implied successful publication |
| Completed or finished early | Local-save confirmation, actual durations/counts, and partial status when applicable |
| Empty history | A clear path to create/start a workout; sample sessions are not presented as real history |
| Publication pending/failed | Local workout stays accessible; status and retry/reconciliation do not imply another workout is needed |

Beep and background behavior:

Beep playback should coexist with music and headphones. No speech synthesis is required. Beep timing uses authoritative phase boundaries. A short countdown is configurable; do not add a complicated sound editor.

Background BLE delivery does not by itself guarantee arbitrary timer callbacks or audio playback. Use the relevant platform mechanisms, reschedule local notification cues after pause/edits, and test screen locking, app switching, audio routes, silent mode, and Focus. Do not use silent-audio loops to keep the process alive. Foreground cues are the primary experience; document actual background cue behavior before promising exact delivery. [Apple background Bluetooth guidance](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html), [local notifications](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app).

Live Activities/Lock Screen controls are a follow-up once the recording foundation works. They are not a dependency for the first installable IPA.

### 8.5 Browser design companion

An interactive browser mockup represents the intended app screens, flows, and states so the user can inspect and refine the design before installing an IPA. It includes the timer, template setup, equipment choices, history/detail graphs, and copy configuration, using clearly identified sample data. Portrait/landscape and light/dark views make the mounted-phone experience reviewable on a desktop browser.

The browser and native shell use corresponding example sessions, labels, units, screen hierarchy, and state semantics. Browser review can change the app design; those decisions belong in this document and should appear in both representations. Browser controls for jumping between sample states sit outside the depicted app interface. Native platform controls remain authoritative for the final iOS experience; the mockup approximates their appearance and cannot validate Bluetooth, HealthKit, ring credit, or background behavior.

The companion is a review artifact. The production application remains native SwiftUI, with its data and timer logic in the native architecture. Its delivery alongside the native shell, local launch instructions, and review workflow are defined in [implementation_plan.md](implementation_plan.md#2-milestone-1--browser-mockup-native-shell-and-ipa-pipeline).

## 9. Graphs, statistics, and comparisons

### 9.1 Workout details

- HR over active elapsed time, with clearly marked work/recovery/warm-up/cooldown boundaries and pauses.
- Aligned panels for speed/incline or resistance/cadence, rendered as per-interval settings.
- A shared cursor showing the phase and readings/settings at a selected time.
- Basic HR-zone coloring based on an editable max-HR value and thresholds; identify estimates. Precise zone-based coaching is not a goal.
- A per-work-interval table: completed duration, equipment settings, average HR, maximum HR, and end HR.
- Missing/stale data is visible. Smoothing is a display option and never overwrites raw samples.

Snapshot the zone configuration used by each workout. Any later recoloring using current zones must be explicit rather than silently changing historical interpretation. The max-HR estimate can be user-entered or age-estimated; choose and document a named estimation method when implemented, with manual override and an option to leave zones unset.

Use actual samples and active time for statistics. Define duration-weighted averaging with a bounded sample-validity window so a long disconnection does not inherit the last HR reading indefinitely. Record sample coverage. Maximum HR uses available observations; end HR requires a sufficiently recent valid observation. Document the chosen freshness thresholds in the metrics implementation and label unavailable results instead of inventing values.

### 9.2 Interval overlay

Align work intervals at elapsed time zero and plot one HR trace per interval. For a 4-minute effort, every trace occupies a 0–4 minute axis. Selecting a trace reveals its duration and entered settings. Keep unequal intervals at their actual durations; do not normalize their length by default.

### 9.3 Comparing workouts

Initially compare two user-selected workouts, suggesting sessions based on the same template. Show aligned workout HR, corresponding intervals, and a table of duration/settings/HR differences. Include gym/equipment context, and call out different settings or template versions. Different machines and resistance scales must remain distinguishable.

Observed differences are presented as data, not automatically labeled fitness improvements. Multi-month trend dashboards can follow later.

## 10. Copying and data export

### Copy Workout

Copy one workout to the clipboard as readable plain text or Markdown. Let the user select fields and save named copy profiles; use checkboxes rather than an arbitrary scripting/template language.

Default contents:

- Date, workout/template name, activity, gym/equipment, and explicit units.
- Planned/completed work-interval counts and warm-up/recovery/cooldown structure.
- Actual active duration and partial-completion status where applicable.
- One row per work interval: duration, speed/incline or resistance/cadence, average HR, maximum HR, and end HR.
- Relevant missing-HR indication and optional notes.

Raw sample streams are exported as files, not inserted into the normal clipboard summary. Recovery-phase rows, zones, and extra context can be optional fields. Multi-workout copying is deferred.

### File export

Export a workout as versioned JSON with its structure, context, source information, and raw samples, plus convenient CSV tables for intervals and HR. Provide a manual all-workouts export using the same schema. Include stable IDs, schema version, ISO 8601 timestamps/time-zone context, active-time mapping, units, pauses, and data gaps. Keep metric-definition/version information alongside derived statistics.

The export represents the local record regardless of Health publishing status. Include provenance for imported Watch data and clearly identify user-entered equipment settings. Use the iOS share sheet and Save to Files. A tested portable export format is required even though backup automation and restoration are deferred.

## 11. Application architecture and update model

### Selected approach

Use **Swift + SwiftUI**, Swift Charts, Core Bluetooth, HealthKit, AVFoundation/UserNotifications, and SQLite through GRDB. Use Swift Package Manager for dependencies and commit an ordinary Xcode project with shared schemes and explicit `.xcconfig` files.

Keep timer/state, analytics, and export logic in a pure Swift module with injected clocks and sensor interfaces. Keep platform adapters separate so deterministic sample data can exercise screens and calculations without a physical H10. Use modern Swift concurrency with explicit isolation for recording and persistence.

| Option | Development updates | Fit for this project |
| --- | --- | --- |
| SwiftUI, selected | Swift changes require rebuilding and signing an updated device binary; previews/simulator speed up local iteration | Direct access to platform behavior and the strongest fit for the requested native experience |
| React Native with a custom development build | JS/TS changes can use Fast Refresh; native module/configuration changes still require a new build | Viable native UI, but HealthKit/BLE/background behavior still requires native integration and an additional runtime |

SwiftUI is selected for direct native integration and development simplicity in an Apple-only sensor app. Native code rebuilds are an accepted tradeoff. [React Native Fast Refresh](https://reactnative.dev/docs/fast-refresh), [Expo development builds](https://docs.expo.dev/develop/development-builds/introduction/).

### What can change without a new IPA

Workout templates, phase durations/counts, equipment settings/profiles, zone settings, copy preferences, and session notes are runtime data. They can change inside CardioLog without rebuilding. A dev-only file import of versioned template/fixture JSON can support repeatable testing without a backend.

### What needs a new IPA

Swift application logic, native screen implementations, BLE/Health integration changes, entitlements, database migration code, and compiled resources require a new binary. No arbitrary Swift hot reload is promised for a FlareStore-signed installation. Apple's platform enforces code signing; previews are a separate development tool. [Apple code signing](https://support.apple.com/guide/security/app-code-signing-process-sec7c917bf14/web), [SwiftUI previews](https://developer.apple.com/documentation/xcode/adding-previews-to-your-interface-files).

Use local SwiftUI previews and the simulator for frequent UI/state iteration, then install device builds for real sensor and OS behavior. Local Xcode deployment is an optional convenience if the available signing assets support it; the required delivery path remains GitHub to FlareStore.

Install updates over the existing app in the same channel. Avoid uninstalling as a normal update step. Keep the channel's bundle ID/signing identity stable and test schema migration plus preservation of recorded workouts. FlareStore documents same-certificate/same-bundle-ID updates. [FlareStore update guidance](https://flarestore.app/faq/).

## 12. Dev and release identities

Use two independently installable channels built from the same source:

| Property | Dev | Release |
| --- | --- | --- |
| Display name | CardioLog Dev | CardioLog |
| Proposed bundle ID | `app.cardiolog.dev` | `app.cardiolog` |
| Shared scheme | `CardioLogDev` | `CardioLog` |
| Configuration | `Dev` | `Release` |
| Visual identity | Distinct dev icon/badge | Normal icon |
| Data | Separate local database/sandbox | Separate local database/sandbox |
| Health publishing | Off initially; explicit opt-in for real-device integration tests | User preference and per-session choice |
| Diagnostics | Build details, connection/sample status, deterministic test fixtures | Normal support/build information |

These bundle IDs are proposed defaults. Verify they are usable with the actual signing/provisioning setup before the first durable installation, then keep them stable. Each channel has its own Health permissions/source. Operating both channels must not automatically publish the same workout twice.

`Dev` is a sideloadable application channel, not a requirement for an attached debugger. Produce its IPA using a standalone, release-style build with diagnostic features enabled through a dedicated compile flag. Disable Xcode's debug-dylib layout for distributed IPAs. Do not require JIT, injected code, `get-task-allow`, or a running development server. Keep a conventional Debug configuration for local Xcode work if useful.

Fixture/simulated workouts are visibly marked, stored separately from real sessions, and never eligible for Health publishing. Opting into Health in Dev applies only to real sensor sessions.

Record semantic version, build number, commit SHA, channel, and schema version in About and diagnostic reports. Keep production HR data and secrets out of routine logs.

## 13. Distribution and delivery requirements

CardioLog has independently installable dev and release channels with stable identities and separate data, as defined above. GitHub Actions produces arm64 iOS-device **unsigned** IPAs for FlareStore to sign and install. CI does not require the user's Apple account, certificate, private key, or provisioning profile. An unsigned IPA is a signing input; installability depends on valid final signing and provisioning.

The delivery contract is:

- Pull requests receive validation without publishing release assets. Relevant changes on the main branch produce dev builds after validation; manual builds can select either or both channels, and version tags produce stable release builds.
- Clearly labeled dev downloads and immutable versioned release downloads include checksums, build/source/toolchain metadata, expected capabilities, and available debugging symbols.
- GitHub Release assets are the normal download experience, with workflow artifacts as a fallback. Private downloads use an authenticated browser followed by Files-to-FlareStore import; no assumption is made that FlareStore can use the browser's GitHub session.
- Both channels run without Xcode, JIT, a debugger, or a development server. Routine updates preserve channel identity, local data, and schema compatibility.
- Required Bluetooth, Health, and notification behavior is supported by the final signed app. HealthKit provisioning failure does not prevent local timing, BLE recording, history, or exports.
- iOS 26 and iOS 27 are explicit compatibility targets. Successful compilation or a skipped test does not establish runtime compatibility.
- Browser design changes can be reviewed independently of an IPA rebuild. Production SwiftUI changes follow the native build/sign/install path.

The repository's existing visibility and access policy are preserved. No backend, home-server service, or public web deployment is required. Workflow layout, commands, toolchain selection, publishing mechanics, and signing/install checks are maintained in [implementation_plan.md](implementation_plan.md#7-infrastructure-implementation-details).

## 14. Product quality requirements

- **Timing integrity:** active durations and phase boundaries remain consistent through pauses and delayed callbacks. Uncertain interruption periods are identified.
- **Data integrity:** missing HR stays missing, recorded observations remain available, and exports retain timestamps, units, provenance, and pause/gap context. Crash recovery retains durably stored data.
- **Health independence:** every core local feature works without Health permission. Health-off sessions produce no CardioLog Health writes, and publication retries reconcile existing records to avoid duplicates.
- **Usability:** the live workout is readable on a mounted phone; large controls, accessible labels, and non-color status cues support quick interaction. Portrait and landscape, light and dark, and increased text size remain usable.
- **Reviewability:** the intended core screens and representative states can be explored in a browser before device installation, with matching examples in the native shell. The browser prototype communicates design and does not certify iOS integrations.
- **Distribution continuity:** dev and release remain distinguishable and independent; updates preserve recorded sessions. Actual signing, sensor, audio/background, and ring behavior require physical-device evidence.

The acceptance procedures and evidence needed to establish these properties are in [implementation_plan.md](implementation_plan.md#6-verification-matrix).
