"""Build an AltStore-compatible source from verified, immutable release artifacts."""
import copy
import datetime
import json
import plistlib
import re
import zipfile
from pathlib import Path
from urllib.parse import quote

FEED_BRANCH = "sideload"
FEED_FILE = "source.json"
ENTRY_FILE = "app-entry.json"
BUNDLE_IDS = {"dev": "app.cardiolog.dev", "release": "app.cardiolog"}


def source_url(repo):
    return f"https://raw.githubusercontent.com/{repo}/{FEED_BRANCH}/{FEED_FILE}"


def numeric_version(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d+(\.\d+){0,2}", value):
        raise ValueError(f"Invalid numeric version: {value!r}")
    parts = tuple(map(int, value.split(".")))
    return parts + (0,) * (3 - len(parts))


def version_key(version):
    return numeric_version(version["version"]), numeric_version(version["buildVersion"])


def make_entry(repo, tag, folder):
    """Read exact identity, versions, permissions, and size from this build."""
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        raise ValueError("Expected a GitHub owner/repository name")
    folder = Path(folder)
    info = json.loads((folder / "build-info.json").read_text())
    channel = info["channel"]
    if channel not in BUNDLE_IDS or not info["unsigned"]:
        raise ValueError("Expected an unsigned CardioLog build")
    if info.get("sourceDirty") or not re.fullmatch(r"[0-9a-f]{40}", info["commit"]):
        raise ValueError("Publish feeds only for clean, committed builds")
    if channel == "release" and tag != "v" + info["version"]:
        raise ValueError("Stable tag does not match the app version")
    if channel == "dev" and not re.fullmatch(r"dev-\d+\.\d+", tag):
        raise ValueError("Dev downloads must use an immutable dev release tag")
    ipas = list(folder.glob("*.ipa"))
    if len(ipas) != 1:
        raise ValueError("Expected exactly one verified IPA")
    ipa = ipas[0]
    with zipfile.ZipFile(ipa) as archive:
        names = [name for name in archive.namelist()
                 if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
        if len(names) != 1:
            raise ValueError("Expected one main app Info.plist")
        app_info = plistlib.loads(archive.read(names[0]))
    for key, expected in {
        "CFBundleIdentifier": BUNDLE_IDS[channel],
        "CFBundleShortVersionString": info["version"],
        "CFBundleVersion": info["build"],
        "MinimumOSVersion": info["minimumOS"],
        "CardioLogCommit": info["commit"],
        "CardioLogChannel": channel,
    }.items():
        if app_info.get(key) != expected:
            raise ValueError(f"IPA/build metadata mismatch: {key}")
    if info["bundleID"] != BUNDLE_IDS[channel]:
        raise ValueError("Build metadata has the wrong bundle ID")
    date = datetime.datetime.fromisoformat(info["createdAt"].replace("Z", "+00:00"))
    if date.tzinfo is None:
        raise ValueError("Build date needs a time zone")
    version = {
        "version": info["version"], "buildVersion": info["build"],
        "date": date.isoformat(), "minOSVersion": info["minimumOS"],
        "downloadURL": f"https://github.com/{repo}/releases/download/{quote(tag, safe='')}/{quote(ipa.name, safe='')}",
        "size": ipa.stat().st_size,
        "localizedDescription": f"Milestone 1 sample shell. Unsigned {channel} build {info['build']}; sign in FlareStore before installing.",
    }
    version_key(version)
    entitlements = plistlib.loads((folder / "expected-entitlements.plist").read_bytes())
    icon = "AppIconDev" if channel == "dev" else "AppIcon"
    app = {
        "name": "CardioLog Dev" if channel == "dev" else "CardioLog",
        "bundleIdentifier": BUNDLE_IDS[channel],
        "developerName": repo.split("/")[0],
        "subtitle": "Interval timer and cardio log · sample preview",
        "localizedDescription": "Native iPhone interval timer with saved templates, workout controls, and sample history. Milestone 1 preview: real sensor recording and Apple Health integration are not implemented yet. Requires your signing certificate in FlareStore.",
        "iconURL": f"https://raw.githubusercontent.com/{repo}/{info['commit']}/App/Assets.xcassets/{icon}.appiconset/Icon.png",
        "tintColor": "#1761D8", "category": "lifestyle",
        "versions": [version],
        "appPermissions": {
            "entitlements": sorted(entitlements),
            "privacy": {key: value for key, value in app_info.items()
                        if key.startswith("NS") and key.endswith("UsageDescription")},
        },
    }
    add_legacy_version(app)
    return {"repository": repo, "commit": info["commit"], "channel": channel, "tag": tag, "app": app}


def add_legacy_version(app):
    """Also support source readers that use the pre-versions-array fields."""
    latest = app["versions"][0]
    app.update({key: latest[key] for key in ("version", "buildVersion", "downloadURL", "size")})
    app["versionDate"] = latest["date"]
    app["versionDescription"] = latest["localizedDescription"]


def merge_source(repo, previous, entry):
    identifier = "app.cardiolog.source." + repo.lower().replace("/", ".")
    if previous is not None and previous.get("identifier") != identifier:
        raise ValueError("Existing source belongs to a different repository")
    if entry["repository"] != repo:
        raise ValueError("Release entry belongs to a different repository")
    incoming = copy.deepcopy(entry["app"])
    bundle = BUNDLE_IDS[entry["channel"]]
    if incoming["bundleIdentifier"] != bundle or len(incoming["versions"]) != 1:
        raise ValueError("Invalid release app entry")
    apps = {app["bundleIdentifier"]: copy.deepcopy(app) for app in (previous or {}).get("apps", [])}
    existing = apps.get(bundle)
    if existing:
        # An older tag finishing later must not become the newest visible version.
        versions = {version_key(v): v for v in existing["versions"]}
        new = incoming["versions"][0]
        key = version_key(new)
        if key in versions and versions[key] != new:
            raise ValueError("Cannot replace an already-published version/build")
        versions[key] = new
        if version_key(existing["versions"][0]) > key:
            incoming = existing
        incoming["versions"] = [versions[k] for k in sorted(versions, reverse=True)]
    add_legacy_version(incoming)
    apps[bundle] = incoming
    ordered = [apps[b] for b in (BUNDLE_IDS["release"], BUNDLE_IDS["dev"]) if b in apps]
    return {
        "name": "CardioLog", "identifier": identifier,
        "subtitle": "Dev and release builds for FlareStore",
        "description": "Unsigned CardioLog builds. Import this source, then sign the chosen app with your certificate. Milestone 1 contains sample workouts only.",
        "website": f"https://github.com/{repo}", "sourceURL": source_url(repo),
        "iconURL": ordered[0]["iconURL"], "tintColor": "#1761D8",
        "apps": ordered, "news": [],
    }
