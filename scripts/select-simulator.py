#!/usr/bin/env python3
import json
import subprocess
import sys
major = sys.argv[1] if len(sys.argv)>1 else '26'
devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))['devices']
choices=[(runtime,d) for runtime,group in devices.items() if f'.iOS-{major}-' in runtime for d in group if d['name'].startswith('iPhone')]
if not choices: raise SystemExit(f'ERROR: iOS {major} simulator unavailable; compatibility has NOT been validated.')
choices.sort(key=lambda item:(item[0], 'Pro Max' in item[1]['name'], item[1]['name']),reverse=True)
print(choices[0][1]['udid'])
