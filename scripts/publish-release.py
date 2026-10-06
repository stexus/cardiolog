#!/usr/bin/env python3
"""Publish verified IPAs, then atomically update the FlareStore source branch."""
import base64
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import quote

from sideload_feed import ENTRY_FILE, FEED_BRANCH, FEED_FILE, make_entry, merge_source, source_url


def gh(*args, check=True):
    return subprocess.run(['gh', *args], check=check, text=True, capture_output=True)


def github_json(endpoint, missing_ok=False):
    result = gh('api', endpoint, check=False)
    if result.returncode == 0:
        return json.loads(result.stdout)
    if missing_ok and '(HTTP 404)' in result.stderr:
        return None
    raise RuntimeError(f'GitHub request failed: {result.stderr.strip()}')


def write_api(endpoint, payload, method):
    with tempfile.TemporaryDirectory() as directory:
        body = Path(directory, 'request.json')
        body.write_text(json.dumps(payload))
        return gh('api', '--method', method, endpoint, '--input', str(body))


def publish_source(repo, sha, entry):
    endpoint = f'repos/{repo}/contents/{FEED_FILE}'
    current = github_json(f'{endpoint}?ref={FEED_BRANCH}', missing_ok=True)
    previous = None
    if current is not None:
        if current.get('encoding') != 'base64':
            raise ValueError('Cannot read the existing source; refusing to replace it')
        previous = json.loads(base64.b64decode(current['content']))
    source = merge_source(repo, previous, entry)
    if source == previous:
        return
    # Create this branch once. Subsequent updates use the file SHA as a compare-and-swap.
    if github_json(f'repos/{repo}/git/ref/heads/{FEED_BRANCH}', missing_ok=True) is None:
        write_api(f'repos/{repo}/git/refs', {'ref': f'refs/heads/{FEED_BRANCH}', 'sha': sha}, 'POST')
    payload = {
        'message': f"Update {entry['app']['name']} source to {entry['app']['version']} ({entry['app']['buildVersion']})",
        'branch': FEED_BRANCH,
        'content': base64.b64encode((json.dumps(source, indent=2) + '\n').encode()).decode(),
    }
    if current is not None:
        payload['sha'] = current['sha']
    write_api(endpoint, payload, 'PUT')


def validate_published_entry(entry, release, repo, sha, channel, tag):
    """Retries may reuse immutable assets, but never advertise a different artifact."""
    for key, expected in {'repository': repo, 'commit': sha, 'channel': channel, 'tag': tag}.items():
        if entry.get(key) != expected:
            raise ValueError(f'Existing release metadata mismatch: {key}')
    if release['draft'] or release['tag_name'] != tag or release['prerelease'] != (channel == 'dev'):
        raise ValueError('Expected a published release in the correct channel')
    assets = [asset for asset in release['assets'] if asset['name'].endswith('.ipa')]
    if len(assets) != 1:
        raise ValueError('Published release must contain exactly one IPA')
    asset = assets[0]
    version = entry['app']['versions'][0]
    expected_url = f"https://github.com/{repo}/releases/download/{quote(tag, safe='')}/{quote(asset['name'], safe='')}"
    if version['downloadURL'] != expected_url or version['size'] != asset['size']:
        raise ValueError('Feed does not match the uploaded IPA')


def main():
    ref = os.environ['GITHUB_REF']
    sha = os.environ['GITHUB_SHA']
    run = int(os.environ['GITHUB_RUN_NUMBER'])
    attempt = int(os.environ['GITHUB_RUN_ATTEMPT'])
    repo = os.environ['GH_REPO']
    channel = 'release' if ref.startswith('refs/tags/v') else 'dev'
    if ref != 'refs/heads/main' and not ref.startswith('refs/tags/v'):
        raise ValueError('Publication is limited to main and version tags')
    if channel not in json.loads(os.environ['CHANNELS']):
        print('No release publication for this channel/ref; download workflow artifacts.')
        return
    folders = list(Path('downloads').glob(f'unsigned-{channel}-*'))
    if len(folders) != 1:
        raise ValueError('Expected one build artifact folder')
    folder = folders[0]
    info = json.loads((folder / 'build-info.json').read_text())
    if info['channel'] != channel or info['commit'] != sha or not info['unsigned']:
        raise ValueError('Build does not match the publication job')
    subprocess.run(['sha256sum', '-c', 'SHA256SUMS.txt'], cwd=folder, check=True)
    tag = os.environ['GITHUB_REF_NAME'] if channel == 'release' else f'dev-{run}.{attempt}'
    entry = make_entry(repo, tag, folder)
    pointer_release = None
    if channel == 'dev':
        head = github_json(f'repos/{repo}/git/ref/heads/main')['object']['sha']
        if head != sha:
            print('Newer main commit exists; keeping artifacts without moving the source or latest-dev.')
            return
        pointer_release = github_json(f'repos/{repo}/releases/tags/latest-dev', missing_ok=True)
        if pointer_release:
            old = re.search(r'cardiolog-run:(\d+)\.(\d+)', pointer_release.get('body') or '')
            if old and (int(old[1]), int(old[2])) >= (run, attempt):
                print('Same or newer dev publication exists.')
                return
    notes = f'''CardioLog {channel} · {info['version']} ({info['build']})

Unsigned iPhone IPA for FlareStore signing. Milestone 1 contains sample screens; real recording and Health integration are unfinished.

Source: {sha}
Toolchain: {info['xcode']} / iOS SDK {info['sdk']}
Minimum iOS: {info['minimumOS']}
Build evidence: {info['ciRunURL']}

[Add this repository source to FlareStore]({source_url(repo)}) after this publication job succeeds. Private repositories still require an authentication method supported by the client; authenticated browser download followed by Files import remains available.

Expected entitlements are not effective provisioning. Physical installation, sensor behavior, and Health/ring credit remain unverified.
'''
    with tempfile.TemporaryDirectory() as directory:
        temp = Path(directory)
        body = temp / 'notes.md'
        body.write_text(notes)
        metadata = temp / ENTRY_FILE
        metadata.write_text(json.dumps(entry, indent=2) + '\n')
        release = github_json(f'repos/{repo}/releases/tags/{tag}', missing_ok=True)
        if release is None:
            assets = sorted(str(p) for p in folder.iterdir()
                            if p.suffix in ['.ipa', '.zip', '.json', '.plist'] or p.name == 'SHA256SUMS.txt')
            options = ['--verify-tag', '--latest'] if channel == 'release' else ['--target', sha, '--prerelease', '--latest=false']
            gh('release', 'create', tag, *assets, str(metadata), *options,
               '--title', f"{entry['app']['name']} {info['version']} ({info['build']})", '--notes-file', str(body))
            release = github_json(f'repos/{repo}/releases/tags/{tag}')
        else:
            # A failed feed update can be retried without replacing any existing IPA.
            published = temp / 'published'
            published.mkdir()
            gh('release', 'download', tag, '--pattern', ENTRY_FILE, '--dir', str(published))
            entry = json.loads((published / ENTRY_FILE).read_text())
        validate_published_entry(entry, release, repo, sha, channel, tag)
        publish_source(repo, sha, entry)
        if channel == 'dev':
            body.write_text(notes + f'\n[Download this dev build](https://github.com/{repo}/releases/tag/{tag})\n\n<!-- cardiolog-run:{run}.{attempt} -->\n')
            if pointer_release is not None:
                gh('api', '--method', 'PATCH', f'repos/{repo}/git/refs/tags/latest-dev', '-f', f'sha={sha}', '-F', 'force=true')
                gh('release', 'edit', 'latest-dev', '--prerelease', '--latest=false', '--title', 'CardioLog Dev · latest build', '--notes-file', str(body))
            else:
                gh('release', 'create', 'latest-dev', '--target', sha, '--prerelease', '--latest=false', '--title', 'CardioLog Dev · latest build', '--notes-file', str(body))
    url = source_url(repo)
    print(f'FlareStore source: {url}')
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as summary:
            summary.write(f'\n### FlareStore source\n\n{url}\n\nPrivate repositories require client authentication or manual IPA import.\n')


if __name__ == '__main__':
    main()
