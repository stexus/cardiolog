# Build and delivery

## Local commands

Use Xcode 26.3 (17C529) with the iOS 26.2 SDK as the baseline. Simulator discovery chooses an installed iPhone in the requested major OS family; local validation used iOS 26.3.1.

```sh
python3 scripts/prepare-fixtures.py --check
swift test --force-resolved-versions
scripts/validate-native.sh 26
scripts/build-ipa.sh dev
scripts/build-ipa.sh release
```

Archives use `generic/platform=iOS`, signing disabled, optimization enabled, and `ENABLE_DEBUG_DYLIB=NO`. Packaging copies the archived app and every bundled resource into `Payload/CardioLog.app`, then uses `ditto` to preserve bundle contents. No Apple account, private key, certificate, profile, JIT, or attached debugger is needed for archiving.

Outputs are under `artifacts/dev/` and `artifacts/release/`: the unsigned IPA, dSYM ZIP, `SHA256SUMS.txt`, `build-info.json`, `expected-entitlements.plist`, and archive log. Device archives remain in `artifacts/archives/`. Build artifacts are intentionally ignored by Git.

The verifier checks ZIP integrity, identity, display name, channel, minimum OS 26.0, versions, usage descriptions, Bluetooth background mode, orientations, asset catalog, privacy manifest, shared fixtures, and every thin Mach-O image. Mach-O `LC_BUILD_VERSION` must identify platform 2 (iOS), not platform 7 (iOS Simulator); arm64 alone is insufficient. Debug dylibs, local/test dependencies, signatures, and provisioning profiles are rejected. Run it manually:

```sh
scripts/verify-ipa.sh /absolute/path/to/CardioLog-unsigned.ipa dev
```

`CARDIOLOG_VERSION` overrides the checked-in `MARKETING_VERSION`; stable tags supply that value in CI. `CARDIOLOG_BUILD_NUMBER` can explicitly override the build. Otherwise CI encodes `100 * run_number + run_attempt` as three numeric components (`1 + ordinal / 10000`, `(ordinal / 100) % 100`, `ordinal % 100`), preserving increasing order for attempts below 100. Do not recreate/rename the build workflow and restart its counter without setting a higher base/version policy. Local builds increment an ignored counter in `artifacts/` and are a separate numbering sequence; use an explicit increasing build when testing updates across local/CI binaries.

Local source without a commit is labeled `uncommitted`; modified/untracked sources are labeled `sourceDirty`. Do not interpret those binaries as an immutable committed release.

## GitHub workflows

Milestone 1 is committed locally; the user will add the remote and push. No remote, CI run, or publication has been performed.

- `ci.yml`: read-only PR checks and reusable validation; browser checks always, native checks only when native/build/shared fixture inputs change. Uses pinned action commits and locked npm/SPM dependencies.
- `build-ipa.yml`: relevant `main` pushes produce dev builds after validation; manual dispatch chooses dev/release/both; numeric `vMAJOR.MINOR.PATCH` tags produce releases. Browser-only and documentation-only pushes do not build an IPA. Other manually selected branches produce workflow artifacts only.
- `ios-27.yml`: explicit separate compatibility lane on `xcode-27`. Requires Xcode 27 and a real installed iOS 27 simulator; absence fails rather than silently skips. The baseline release pipeline is separate during bootstrap; therefore a published baseline build does not establish iOS 27 compatibility.

Native baseline jobs explicitly select `/Applications/Xcode_26.3.app/Contents/Developer` on `macos-26` and fail if absent. Cache entries contain only downloaded Swift repositories, keyed by runner architecture, Xcode, and lockfile; mutable build products and user data are not cached. The Xcode 27 lane logs the exact runner-selected preview toolchain.

Action SHAs were resolved from upstream v4 tags at implementation. The baseline Xcode installation and `xcode-27` label were checked against [GitHub's runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md) and [Xcode 27 preview announcement](https://github.com/actions/runner-images/issues/14404). Those inventories describe available infrastructure; they are not successful CardioLog workflow runs.

Only the trusted publication job receives `contents: write`. Stable releases refuse to overwrite existing tags/assets. Dev builds are immutable `dev-RUN.ATTEMPT` prereleases; `latest-dev` is a serialized prerelease pointer linking to the current dev download. Source-head and run-order guards prevent an older run moving it backward. Dev releases are excluded from the stable latest-release designation. Workflow artifacts are retained as a download fallback. Manual release builds from `main` remain workflow artifacts unless built from a version tag.

## Signing later

An unsigned IPA is not directly installable. After browser review, download it in an authenticated browser if the repository is private, import from Files into FlareStore, and sign with the user's certificate. Keep the bundle IDs stable and preserve HealthKit provisioning. The entitlement sidecar expresses expected capabilities; it does not grant them.

## FlareStore repository readiness

The source is ready to push and the workflows are configured to build unsigned IPAs, but a GitHub project URL is not itself a FlareStore source. FlareStore documents repository feeds in AltStore, SideStore, or ESign formats. Those feeds describe app metadata, versions, icons, and downloadable IPA URLs. No such feed is generated or hosted by this project yet. [FlareStore import and repository instructions](https://flarestore.app/guide/ios/), [repository JSON format overview](https://flarestore.app/repo-creator/).

After pushing `main`, wait for **Build unsigned IPA** to pass. The `latest-dev` prerelease links to the immutable dev release containing the IPA. On the iPhone, download that IPA through the authenticated GitHub browser session, then use **FlareStore → Import → Library → Sign → Install**. A numeric version tag such as `v0.1.0` triggers the separate release-channel build. Do not publish a version tag until ready to designate that version; the current app is a Milestone 1 sample shell.

To make CardioLog browsable and updatable through **Add Repository**, add a generated source JSON with separate dev/release entries, update it only after successful IPA publication, and give it a stable URL whose feed, icons, and IPA assets FlareStore can retrieve. For a private repository, an accessible hosting/authentication arrangement is still needed; the user's browser GitHub session cannot be assumed to authenticate FlareStore. Do not change repository visibility or embed credentials in a feed to bypass that requirement. This convenience remains deferred as described in `implementation_plan.md` §7.5.

CI publication and FlareStore installation still require an actual remote workflow run and a signed physical-device test; local archive verification does not establish either.

## Physical-device acceptance

Before declaring device acceptance, test both channels' standalone launch and separate data, an update over each existing installation, effective entitlements and Health authorization/read/write, H10 connection/reconnect, lock/background/audio routes, and actual Health/Bevel/ring results. These are Milestone 2 activities and have not been verified by the shell.
