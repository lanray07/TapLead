"""Check exported IPA capabilities without printing credentials or contact data."""
import os,pathlib,plistlib
temp=pathlib.Path(os.environ['RUNNER_TEMP'])
bundle=os.environ['TAPLEAD_RESOLVED_BUNDLE'];group=os.environ['TAPLEAD_RESOLVED_GROUP']
app=temp/'verify-ipa/Payload/TapLead.app'
for kind,path,identifier in [('app',app,bundle),('widget',app/'PlugIns/TapLeadWidget.appex',bundle+'.widget')]:
    entitlements=plistlib.loads((temp/(kind+'-entitlements.plist')).read_bytes())
    info=plistlib.loads((path/'Info.plist').read_bytes())
    assert info['CFBundleIdentifier']==identifier,kind+' bundle identifier mismatch'
    assert str(info['CFBundleVersion'])==str(int(os.environ['GITHUB_RUN_NUMBER'])+1000),kind+' build number mismatch'
    assert entitlements.get('com.apple.security.application-groups')==[group],kind+' missing shared App Group'
    assert not entitlements.get('get-task-allow',False),kind+' unexpectedly allows debugging'
    if kind=='app':
        assert entitlements.get('com.apple.developer.applesignin')==['Default'],'Missing Apple sign-in entitlement'
        assert not any('nfc' in key.lower() for key in entitlements),'NFC entitlement must be absent from this release'
        assert 'NFCReaderUsageDescription' not in info,'Retired NFC permission must be absent'
    print('Verified distribution signature, bundle, build and capabilities:',kind)
