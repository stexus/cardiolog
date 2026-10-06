#!/usr/bin/env python3
import datetime
import json
import os
import subprocess
import sys
from pathlib import Path
output,channel,version,build,commit=sys.argv[1:]
def command(*args): return subprocess.check_output(args,text=True).strip()
info={
 'channel':channel,'bundleID':'app.cardiolog.dev' if channel=='dev' else 'app.cardiolog',
 'version':version,'build':build,'commit':commit,'sourceDirty':bool(command('git','status','--porcelain')),
 'xcode':command('xcodebuild','-version'),'sdk':command('xcrun','--sdk','iphoneos','--show-sdk-version'),
 'minimumOS':'26.0','schemaVersion':1,'fixtureSchemaVersion':1,'unsigned':True,
 'createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'ciRunURL':f'https://github.com/{os.environ["GITHUB_REPOSITORY"]}/actions/runs/{os.environ["GITHUB_RUN_ID"]}' if 'GITHUB_RUN_ID' in os.environ else None,
 'expectedCapabilities':['HealthKit (requires final provisioning)','Bluetooth central background mode'],
 'limitations':['Milestone 1 fixture shell; no real recording','Unsigned; must be signed before installation','Device integration and iOS 27 runtime are not certified by this archive']
}
Path(output,'build-info.json').write_text(json.dumps(info,indent=2)+'\n')
