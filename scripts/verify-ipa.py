#!/usr/bin/env python3
"""Verify unsigned packaging, identity, resources, and LC_BUILD_VERSION (not just arm64)."""
import argparse
import json
import plistlib
import re
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument('ipa',type=Path)
parser.add_argument('channel',choices=['dev','release'])
parser.add_argument('--version')
parser.add_argument('--build')
args = parser.parse_args()
expected_id = 'app.cardiolog.dev' if args.channel == 'dev' else 'app.cardiolog'
expected_name = 'CardioLog Dev' if args.channel == 'dev' else 'CardioLog'
with zipfile.ZipFile(args.ipa) as archive:
    assert archive.testzip() is None, 'Corrupt ZIP'
    names = archive.namelist()
    assert all(not n.startswith('/') and '..' not in Path(n).parts for n in names), 'Unsafe ZIP path'
    apps = {n.split('/')[1] for n in names if n.startswith('Payload/') and len(n.split('/')) > 2 and n.split('/')[1].endswith('.app')}
    assert len(apps) == 1, 'Expected exactly one Payload/*.app'
    prefix = 'Payload/' + apps.pop() + '/'
    info = plistlib.loads(archive.read(prefix + 'Info.plist'))
    assert info['CFBundleIdentifier'] == expected_id
    assert info['CFBundleDisplayName'] == expected_name
    assert info['CardioLogChannel'] == args.channel
    assert info['MinimumOSVersion'] == '26.0'
    assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS']
    assert re.fullmatch(r'\d+\.\d+\.\d+',info['CFBundleShortVersionString'])
    assert re.fullmatch(r'\d+(\.\d+){0,2}',info['CFBundleVersion'])
    if args.version: assert info['CFBundleShortVersionString'] == args.version
    if args.build: assert info['CFBundleVersion'] == args.build
    assert all(info.get(key) for key in ['NSBluetoothAlwaysUsageDescription','NSHealthShareUsageDescription','NSHealthUpdateUsageDescription','CardioLogCommit'])
    assert set(info['UIBackgroundModes']) == {'bluetooth-central'}
    assert {'UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'} <= set(info['UISupportedInterfaceOrientations'])
    for resource in ['Assets.car','PrivacyInfo.xcprivacy']:
        assert prefix + resource in names, f'Missing {resource}'
    fixtures = [n for n in names if n.startswith(prefix) and n.endswith('/sessions.json')]
    assert len(fixtures) == 1, 'Missing / duplicated shared fixtures'
    fixture = json.loads(archive.read(fixtures[0]))
    assert fixture['schemaVersion'] == 1 and len(fixture['workouts']) >= 3
    assert all(w['isSimulation'] for w in fixture['workouts'])
    assert not any('debug.dylib' in n or '__preview' in n or '_CodeSignature/' in n or n.endswith('embedded.mobileprovision') for n in names), 'Signed or debugger-dependent bundle'
    checked = 0
    for name in names:
        if not name.startswith(prefix) or name.endswith('/'): continue
        binary = archive.read(name)
        if binary[:4] != b'\xcf\xfa\xed\xfe': continue
        magic,cpu,subtype,filetype,ncmds,sizeofcmds,flags,reserved = struct.unpack_from('<8I',binary)
        assert cpu == 0x100000c, f'Non-arm64 binary: {name}'
        offset=32; platforms=[]
        for _ in range(ncmds):
            cmd,size=struct.unpack_from('<II',binary,offset)
            assert size>=8 and offset+size<=len(binary)
            if cmd==0x32:
                platform,minos,sdk,ntools=struct.unpack_from('<4I',binary,offset+8)
                platforms.append(platform)
            if cmd in [0xc,0x80000018,0x8000001f]:
                string_offset=struct.unpack_from('<I',binary,offset+8)[0]
                dependency=binary[offset+string_offset:offset+size].split(b'\0')[0].decode()
                assert not any(s in dependency.lower() for s in ['debug.dylib','xctest','injection','/simulator','/users/']), f'Debug/local dependency: {dependency}'
            assert cmd != 0x1d, f'Unexpected code signature: {name}'
            offset+=size
        assert platforms and set(platforms)=={2}, f'Not an iOS device binary: {name} (platforms {platforms})'
        checked+=1
    assert checked>=1
    executable=archive.read(prefix+info['CFBundleExecutable'])
    assert executable[:4]==b'\xcf\xfa\xed\xfe'
print(f'PASS {args.channel}: {expected_id} {info["CFBundleShortVersionString"]} ({info["CFBundleVersion"]}), {checked} unsigned arm64 iOS binary/binaries, fixtures + resources present')
