import json, subprocess
devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))['devices']
for runtime,values in sorted(devices.items(),reverse=True):
    if 'iOS' not in runtime: continue
    phones=[device for device in values if device.get('isAvailable') and 'iPhone' in device['name']]
    if phones:
        selected=next((phone for phone in phones if 'Pro Max' in phone['name']),phones[0])
        print('SIMULATOR_ID='+selected['udid'])
        break
else: raise SystemExit('No available iPhone simulator is installed on this runner.')
