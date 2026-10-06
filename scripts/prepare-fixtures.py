#!/usr/bin/env python3
"""Copy the authoritative fixtures into self-contained browser / Swift resources."""
import argparse
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--check", action="store_true")
args = parser.parse_args()
source = root / "Fixtures/sessions.json"
data = source.read_bytes()
library = json.loads(data)
assert library["schemaVersion"] == 1
assert all(w["isSimulation"] for w in library["workouts"])
for workout in library["workouts"]:
    assert all(0 <= p["elapsed"] <= workout["activeSeconds"] for p in workout["samples"])
    assert sum(i["actualSeconds"] for i in workout["intervals"]) == workout["activeSeconds"]
for relative in ["mockup/fixtures/sessions.json", "Sources/CardioLogCore/Resources/sessions.json"]:
    target = root / relative
    if args.check:
        assert target.read_bytes() == data, f"Stale fixtures: run {__file__}"
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
print("Shared fixtures validated" + ("" if args.check else " and copied"))
