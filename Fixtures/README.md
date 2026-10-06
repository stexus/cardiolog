# Shared fixtures · schema 1

`sessions.json` is the only authoritative sample library. Its templates, equipment profiles, workouts, HR traces, gaps, and nine named preview states feed both representations. All workouts must have `isSimulation: true`.

- `four-by-four`: 5-minute warm-up, four 4-minute efforts, three 3-minute recoveries, 5-minute cooldown; 35 minutes total; an explicit HR gap at active seconds 1020–1110.
- `steady-bike`: 3-minute warm-up, 20-minute work interval, 3-minute cooldown; 26 minutes total.
- `partial`: the same treadmill structure stopped at active second 840. Future intervals have zero **actual duration**, not zero HR.

Equipment settings are entered values: mph / incline percent or machine-specific resistance / rpm. Null means missing. HR samples are illustrative observations at active seconds, grouped by contiguous `segment`; gaps must never be bridged by a chart line. These fixture objects are not the final production export schema.

Run `python3 scripts/prepare-fixtures.py` after editing. Commit the two generated copies so a checkout is immediately viewable and buildable. CI uses `--check` to verify byte-for-byte agreement.
