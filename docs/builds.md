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

- `ci.yml`: read-only PR checks and reusable validation; browser and feed/publication checks always, native checks only when native/build/shared fixture inputs change. Uses pinned action commits and locked npm/SPM dependencies.
- `build-ipa.yml`: relevant `main` pushes produce dev builds after validation; manual dispatch chooses dev/release/both; numeric `vMAJOR.MINOR.PATCH` tags produce releases. Browser-only and documentation-only pushes do not build an IPA. Other manually selected branches produce workflow artifacts only.
- `ios-27.yml`: explicit separate compatibility lane on `xcode-27`. Requires Xcode 27 and a real installed iOS 27 simulator; absence fails rather than silently skips. The baseline release pipeline is separate during bootstrap; therefore a published baseline build does not establish iOS 27 compatibility.

Native baseline jobs explicitly select `/Applications/Xcode_26.3.app/Contents/Developer` on `macos-26` and fail if absent. Cache entries contain only downloaded Swift repositories, keyed by runner architecture, Xcode, and lockfile; mutable build products and user data are not cached. The Xcode 27 lane logs the exact runner-selected preview toolchain.

Action SHAs were resolved from upstream v4 tags at implementation. The baseline Xcode installation and `xcode-27` label were checked against [GitHub's runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md) and [Xcode 27 preview announcement](https://github.com/actions/runner-images/issues/14404). Those inventories describe available infrastructure; they are not successful CardioLog workflow runs.

Only the trusted publication job receives `contents: write`. Stable releases never overwrite existing tags/assets; retries reuse the original published `app-entry.json` after checking its source commit and IPA asset. Dev builds are immutable `dev-RUN.ATTEMPT` prereleases; `latest-dev` is a serialized prerelease pointer linking to the current dev download. Source-head and run-order guards prevent an older run moving it backward. Dev releases are excluded from the stable latest-release designation. Workflow artifacts are retained as a download fallback. Manual release builds from `main` remain workflow artifacts unless built from a version tag.

## Signing later

An unsigned IPA is not directly installable. After browser review, download it in an authenticated browser if the repository is private, import from Files into FlareStore, and sign with the user's certificate. Keep the bundle IDs stable and preserve HealthKit provisioning. The entitlement sidecar expresses expected capabilities; it does not grant them.

## FlareStore repository feed

After pushing `main`, wait for **Build unsigned IPA** to finish its publication job. It uploads the immutable dev IPA and then creates/updates `source.json` on the dedicated `sideload` branch. Add this URL in **FlareStore → Add Repository**, substituting the GitHub owner and repository name:

```text
https://raw.githubusercontent.com/OWNER/REPO/sideload/source.json
```

The actual URL is printed in the Actions job summary and release notes. No GitHub Pages configuration or separate server is needed. The feed initially lists **CardioLog Dev**. Publishing a numeric version tag such as `v0.1.0` adds the independent **CardioLog** release entry. Manual release builds from `main` remain downloadable workflow artifacts; they do not create a stable source entry. The current app is still a Milestone 1 sample shell.

`scripts/sideload_feed.py` generates the AltStore-compatible app entry from the verified IPA, build manifest, and expected entitlements. It includes exact bundle ID, semantic/build versions, minimum iOS, archive size, permissions, a commit-pinned icon URL, and an immutable IPA URL. The `versions` array and legacy top-level version fields support different source readers. Each immutable release includes `app-entry.json`, preserving its feed metadata for retries. Existing version history and the other channel remain intact; numeric version/build ordering prevents an older tag finishing late from rolling the feed backward. [FlareStore source support](https://flarestore.app/guide/ios/), [AltStore source fields](https://faq.altstore.io/developers/make-a-source), [version ordering](https://faq.altstore.io/developers/updating-apps).

The serialized publication job updates the feed only after all release assets upload successfully and the referenced IPA's name/size are confirmed. The GitHub Contents API commits the entire JSON atomically and checks the previous file SHA to avoid overwriting a concurrent change. The `sideload` branch is created from the first published source commit and thereafter receives only feed updates; `main` is not modified. Reserve that branch/file for generated output and allow the workflow token to create/update it if branch rules are configured. A failed feed update can be retried using the existing immutable release metadata without replacing the IPA.

Repository visibility is unchanged. For a private repository, FlareStore must authenticate access to the feed, icons, and IPA assets; support for that has not been established. No credentials are embedded in the feed. The fallback is authenticated GitHub download, then **FlareStore → Import → Library → Sign → Install**. CI publication and FlareStore installation still require an actual remote workflow run and a signed physical-device test.

Run the local feed/publication checks with:

```sh
python3 -m unittest discover -s scripts -p 'test_sideload_feed.py' -v
```

The tests use synthetic IPA metadata and mocked GitHub responses; they do not publish anything.

## Physical-device acceptance

Before declaring device acceptance, test both channels' standalone launch and separate data, an update over each existing installation, effective entitlements and Health authorization/read/write, H10 connection/reconnect, lock/background/audio routes, and actual Health/Bevel/ring results. These are Milestone 2 activities and have not been verified by the shell.
