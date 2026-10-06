#!/usr/bin/env python3
"""Only run in the trusted publication job, after validation and package verification."""
import json
import os
import subprocess
import tempfile
from pathlib import Path

def gh(*args, check=True): return subprocess.run(['gh',*args],check=check,text=True,capture_output=True)
ref=os.environ['GITHUB_REF']
sha=os.environ['GITHUB_SHA']
run=int(os.environ['GITHUB_RUN_NUMBER'])
attempt=int(os.environ['GITHUB_RUN_ATTEMPT'])
repo=os.environ['GH_REPO']
channel='release' if ref.startswith('refs/tags/') else 'dev'
if channel not in json.loads(os.environ['CHANNELS']):
    print('No release publication for this channel/ref; download workflow artifacts.')
    raise SystemExit(0)
folders=list(Path('downloads').glob(f'unsigned-{channel}-*'))
assert len(folders)==1
folder=folders[0]
info=json.loads((folder/'build-info.json').read_text())
assert info['channel']==channel and info['commit']==sha and info['unsigned']
# Artifact hashes are checked again after download, before publishing.
subprocess.run(['sha256sum','-c','SHA256SUMS.txt'],cwd=folder,check=True)
assets=[str(p) for p in folder.iterdir() if p.suffix in ['.ipa','.zip','.json','.plist'] or p.name=='SHA256SUMS.txt']
notes=f'''CardioLog {channel} · {info['version']} ({info['build']})

Unsigned iPhone IPA for later FlareStore signing. Milestone 1 contains fixture-backed screens; real recording and Health integration are unfinished.

Source: {sha}
Toolchain: {info['xcode']} / iOS SDK {info['sdk']}
Minimum iOS: {info['minimumOS']}
Build evidence: {info['ciRunURL']}

Download the IPA through an authenticated browser if this repository is private, then import it from Files into FlareStore. Expected entitlements are a signing checklist, not effective provisioning. Physical installation, sensor behavior, and Health/ring credit remain unverified.
'''
with tempfile.TemporaryDirectory() as temp:
    body=Path(temp,'notes.md'); body.write_text(notes)
    if channel=='release':
        tag=os.environ['GITHUB_REF_NAME']
        assert tag == 'v'+info['version']
        if gh('release','view',tag,check=False).returncode==0:
            raise SystemExit('Stable release already exists; immutable assets will not be overwritten.')
        gh('release','create',tag,*assets,'--verify-tag','--title',f"CardioLog {info['version']}",'--notes-file',str(body),'--latest')
    else:
        # Serialization plus source-head / run checks prevent a slow older run replacing latest-dev.
        head=json.loads(gh('api',f'repos/{repo}/git/ref/heads/main').stdout)['object']['sha']
        if head!=sha:
            print('Newer main commit exists; keeping these artifacts without moving latest-dev.')
            raise SystemExit(0)
        existing=gh('release','view','latest-dev','--json','body',check=False)
        if existing.returncode==0:
            text=json.loads(existing.stdout)['body']
            import re
            old=re.search(r'cardiolog-run:(\d+)\.(\d+)',text)
            if old and (int(old[1]),int(old[2])) >= (run,attempt):
                print('Same or newer dev publication exists.'); raise SystemExit(0)
        immutable=f'dev-{run}.{attempt}'
        if gh('release','view',immutable,check=False).returncode != 0:
            gh('release','create',immutable,*assets,'--target',sha,'--prerelease','--latest=false','--title',f"CardioLog Dev {info['build']}",'--notes-file',str(body))
        pointer=notes+f'\n[Download this dev build](https://github.com/{repo}/releases/tag/{immutable})\n\n<!-- cardiolog-run:{run}.{attempt} -->\n'
        body.write_text(pointer)
        if existing.returncode==0:
            # Assets live at immutable dev tags. latest-dev is a serialized, lightweight download pointer.
            gh('api','--method','PATCH',f'repos/{repo}/git/refs/tags/latest-dev','-f',f'sha={sha}','-F','force=true')
            gh('release','edit','latest-dev','--prerelease','--latest=false','--title','CardioLog Dev · latest build','--notes-file',str(body))
        else:
            gh('release','create','latest-dev','--target',sha,'--prerelease','--latest=false','--title','CardioLog Dev · latest build','--notes-file',str(body))
        print(f'https://github.com/{repo}/releases/tag/latest-dev')
