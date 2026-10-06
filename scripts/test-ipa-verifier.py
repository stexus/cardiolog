#!/usr/bin/env python3
"""Regression-check the package gate against corrupted identity and simulator platform."""
import plistlib
import struct
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
source=Path(sys.argv[1])
root=Path(__file__).resolve().parent.parent
with zipfile.ZipFile(source) as archive:
    contents={name:archive.read(name) for name in archive.namelist()}
info_name=next(name for name in contents if name.count('/')==2 and name.endswith('/Info.plist'))
info=plistlib.loads(contents[info_name])
exe=info_name.removesuffix('Info.plist')+info['CFBundleExecutable']
with tempfile.TemporaryDirectory() as directory:
    for case in ['wrong-channel','simulator-platform','missing-fixtures']:
        altered=contents.copy()
        if case=='wrong-channel':
            bad=info.copy();bad['CFBundleIdentifier']='app.cardiolog';altered[info_name]=plistlib.dumps(bad)
        elif case=='simulator-platform':
            binary=bytearray(altered[exe]);ncmds=struct.unpack_from('<I',binary,16)[0];offset=32
            for _ in range(ncmds):
                cmd,size=struct.unpack_from('<II',binary,offset)
                if cmd==0x32:struct.pack_into('<I',binary,offset+8,7)
                offset+=size
            altered[exe]=binary
        else:
            altered={name:data for name,data in altered.items() if not name.endswith('/sessions.json')}
        path=Path(directory,case+'.ipa')
        with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED) as archive:
            for name,data in altered.items():archive.writestr(name,data)
        result=subprocess.run([sys.executable,str(root/'scripts/verify-ipa.py'),str(path),'dev'],capture_output=True,text=True)
        assert result.returncode!=0,f'Incorrect package passed: {case}'
        print(f'PASS: rejects {case}')
