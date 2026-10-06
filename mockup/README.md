# CardioLog browser companion

This is a small, dependency-free HTML/CSS/JavaScript design preview. All workouts and heart rates are samples. The installed application is native SwiftUI.

From the repository root:

```sh
python3 scripts/prepare-fixtures.py
python3 -m http.server 4173 --bind 0.0.0.0 --directory mockup
```

Open **http://10.0.0.242:4173/** from the LAN during this review session, or **http://127.0.0.1:4173/** on this machine. The LAN IP may change; inspect `ifconfig` if necessary. Binding `0.0.0.0` supports the user's headless SSH workflow. Serve only `mockup/`, not the repository root. For a loopback-only server, use `--bind 127.0.0.1`.

Native/browser screenshot comparisons are available at `/review/` after running `python3 scripts/prepare-review.py`.

Use the controls outside the phone to select all nine sample states, light/dark appearance, and portrait/landscape. The layout also fits a mobile browser. Direct state links work, for example `/?state=paused` or `/?state=completed`.

The current aesthetic is cool blue: icy light surfaces, blue slate dark surfaces, vivid/pale blue actions, and glass-style navigation capsules. Switch Appearance to compare the two. The browser approximates glass using CSS; the SwiftUI shell uses native Liquid Glass navigation and prominent action buttons. Content cards stay readable and visually quieter than the controls. Shared palette decisions are recorded in `design.md` §8.3; native adaptive color assets are in `App/Assets.xcassets/`.

Try:

1. The last-used timer opens on launch. Use the top-left Timers back button or the Timers tab to browse saved templates. Choose one to open its setup; Start stays pinned above the tabs while details scroll.
2. Edit → adjust work/recovery durations and settings, repetition count, and final recovery. The duration preview updates immediately. Use the template options menu to duplicate, or New from the Timers list to create a template.
3. Start sample workout → Pause / Resume → Edit Next. The scope preview lists the affected work intervals. Current and earlier settings are frozen.
4. Add Interval → inspect the increased planned time → Finish → confirm. The actual partial duration is saved in this browser's separate preview history.
5. History → choose a sample → select an interval on the graph or table → Copy Workout → change fields and inspect the text.
6. Timers → Steady ride → choose the Home spin bike. Resistance is specific to that equipment profile.

`styles.css` owns palette, spacing, typography, and layout. `app.js` owns preview interactions, `index.html` owns the outer review controls. Refresh after edits; no IPA rebuild is needed. `Fixtures/sessions.json` is authoritative; do not edit the copies in `mockup/fixtures/` or `Sources/CardioLogCore/Resources/`. Run the preparation script after changing fixtures, or `--check` to detect stale copies.

Newly simulated sessions contain no recorded HR, even when an illustrative reading is visible. Only historical fixtures have sample traces. Missing graph sections stay missing. Preview statistics use forward duration weighting with a 15-second validity cap; end HR requires a reading within 15 seconds. These are preview calculations, not production analytics acceptance.

History, copy options, saved templates, equipment choices, and the last-used template use browser local storage. These persist across reloads in the same browser at the same origin; a changed LAN IP is a different origin. The native shell stores its own preview template catalog and selection in app preferences. Diagnostic sample-state selection does not overwrite the remembered template. Settings → Restore sample history resets only preview history. The empty-history selector hides examples without deleting them. Clipboard permission may be unavailable over HTTP on the LAN: select/copy the text preview manually if the browser denies access. Export downloads explicitly marked sample JSON; the production export schema comes in Milestone 4.

BLE, Health, notification/audio/background behavior, and native sharing are not validated by this preview.

## Browser checks

```sh
npm ci --prefix mockup
npm test --prefix mockup
```

Local tests use installed Google Chrome. CI installs Playwright Chromium. Tests exercise controls, sample states, scope, saved history, copy selections, and mobile layout, and write screenshots to `artifacts/`. Node dependencies exist only for testing; serving the preview needs Python alone.
