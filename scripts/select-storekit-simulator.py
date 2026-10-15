"""Select an installed simulator unaffected by the iOS 26.3–26.5 CLI SKTestSession defect.

Fail explicitly if none is installed; never substitute a passing mock for StoreKit.
"""
import json
import os
import re
import subprocess
import sys

devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))['devices']
family=os.environ.get('DEVICE_FAMILY','iPhone')
print('Available simulator runtimes: '+', '.join(devices),file=sys.stderr)
supported=[]
for runtime,values in devices.items():
    match=re.search(r'iOS-(\d+)-(\d+)',runtime)
    if not match:
        continue
    version=tuple(map(int,match.groups()))
    # Apple developer reports identify 26.1 as unaffected. Use an installed older
    # runtime for local StoreKit only; this does not claim iPadOS 27 coverage.
    if version > (26,2) or version < (17,0):
        continue
    candidates=[d for d in values if d.get('isAvailable') and family in d['name']]
    if candidates:
        supported.append((version,runtime,candidates))
if not supported:
    raise SystemExit('No compatible local StoreKit simulator is installed. StoreKit tests were NOT run.')
version,runtime,candidates=max(supported,key=lambda row:(row[0]==(26,1),row[0]))
device=next((d for d in candidates if '11-inch' in d['name'] and 'M4' in d['name']),None)
device=device or next((d for d in candidates if 'Pro' in d['name']),candidates[0])
print('Local StoreKit test device: '+device['name']+' '+runtime,file=sys.stderr)
print('SIMULATOR_ID='+device['udid'])
