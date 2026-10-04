"""Run only on the secret-backed GitHub runner. Never print keys or JWTs.
Discovers the existing TapLead app, configures automatic signing, and exports an IPA.
It does not upload a build to TestFlight or submit it for App Review.
"""
import base64,json,os,pathlib,plistlib,time,urllib.request,urllib.parse
from cryptography.hazmat.primitives import hashes,serialization
from cryptography.hazmat.primitives.asymmetric import ec,utils
import yaml

required=['APPLE_TEAM_ID','APP_STORE_CONNECT_API_KEY_ID','APP_STORE_CONNECT_API_PRIVATE_KEY','APP_STORE_CONNECT_ISSUER_ID','RUNNER_TEMP','GITHUB_ENV']
missing=[name for name in required if not os.environ.get(name)]
if missing:raise SystemExit('Missing required signing configuration: '+', '.join(missing))
env=os.environ
pem=env['APP_STORE_CONNECT_API_PRIVATE_KEY'].replace('\\n','\n').strip()
if not pem.startswith('-----BEGIN'):pem=base64.b64decode(pem).decode('utf8')
key=serialization.load_pem_private_key(pem.encode(),password=None)
def b64(data):return base64.urlsafe_b64encode(data).rstrip(b'=')
header=b64(json.dumps({'alg':'ES256','kid':env['APP_STORE_CONNECT_API_KEY_ID'],'typ':'JWT'},separators=(',',':')).encode())
ts=int(time.time())
payload=b64(json.dumps({'iss':env['APP_STORE_CONNECT_ISSUER_ID'],'iat':ts,'exp':ts+600,'aud':'appstoreconnect-v1'},separators=(',',':')).encode())
unsigned=header+b'.'+payload
r,s=utils.decode_dss_signature(key.sign(unsigned,ec.ECDSA(hashes.SHA256())))
token=(unsigned+b'.'+b64(r.to_bytes(32,'big')+s.to_bytes(32,'big'))).decode()
app_id=env.get('TAPLEAD_APP_ID','').strip()
endpoint='https://api.appstoreconnect.apple.com/v1/apps/'+urllib.parse.quote(app_id) if app_id else 'https://api.appstoreconnect.apple.com/v1/apps?filter[name]=TapLead&limit=50'
request=urllib.request.Request(endpoint,headers={'Authorization':'Bearer '+token})
try:
    with urllib.request.urlopen(request,timeout=30) as response:data=json.load(response)['data']
except urllib.error.HTTPError as error:
    raise SystemExit(f'App Store Connect rejected app lookup (HTTP {error.code}). Check API key role and issuer.') from None
apps=data if isinstance(data,list) else [data]
if len(apps)!=1:raise SystemExit('Could not identify one existing TapLead app. Set repository variable TAPLEAD_APP_ID to its numeric App Store ID.')
app=apps[0]
if 'taplead' not in app['attributes']['name'].lower():raise SystemExit('The selected App Store app does not match TapLead.')
bundle=app['attributes']['bundleId']
group=env.get('TAPLEAD_APP_GROUP','').strip() or 'group.'+bundle+'.shared'
spec_path=pathlib.Path('project.yml');spec=yaml.safe_load(spec_path.read_text())
spec['settings']['base']['DEVELOPMENT_TEAM']=env['APPLE_TEAM_ID']
spec['settings']['base']['CODE_SIGN_STYLE']='Automatic'
spec['settings']['base']['CURRENT_PROJECT_VERSION']=int(env.get('GITHUB_RUN_NUMBER','1'))+1000
spec['targets']['TapLead']['settings']['base']['PRODUCT_BUNDLE_IDENTIFIER']=bundle
spec['targets']['TapLeadWidget']['settings']['base']['PRODUCT_BUNDLE_IDENTIFIER']=bundle+'.widget'
for target in ['TapLead','TapLeadWidget']:
    spec['targets'][target]['entitlements']['properties']['com.apple.security.application-groups']=[group]
    spec['targets'][target]['info']['properties']['CFBundleVersion']='$(CURRENT_PROJECT_VERSION)'
    spec['targets'][target]['info']['properties']['CFBundleShortVersionString']='$(MARKETING_VERSION)'
for key,variable in [('TapLeadAPIURL','TAPLEAD_API_URL'),('TapLeadPrivacyURL','TAPLEAD_PRIVACY_URL'),('TapLeadTermsURL','TAPLEAD_TERMS_URL')]:
    value=env.get(variable,'').strip()
    if value and not value.startswith('https://'):raise SystemExit(variable+' must use HTTPS.')
    spec['targets']['TapLead']['info']['properties'][key]=value
spec_path.write_text(yaml.safe_dump(spec,sort_keys=False))
for file in [pathlib.Path('iOS/TapLead/Services/AppStore.swift'),pathlib.Path('iOS/Widget/TapLeadWidget.swift')]:
    file.write_text(file.read_text().replace('group.com.taplead.shared',group))
key_path=pathlib.Path(env['RUNNER_TEMP'])/('AuthKey_'+env['APP_STORE_CONNECT_API_KEY_ID']+'.p8')
key_path.write_text(pem+'\n');key_path.chmod(0o600)
with open(env['GITHUB_ENV'],'a') as output:output.write('ASC_KEY_PATH='+str(key_path)+'\n')
with open(env['GITHUB_ENV'],'a') as output:
    output.write('TAPLEAD_RESOLVED_BUNDLE='+bundle+'\nTAPLEAD_RESOLVED_GROUP='+group+'\n')
options={'method':'app-store-connect','destination':'export','signingStyle':'automatic','teamID':env['APPLE_TEAM_ID'],'manageAppVersionAndBuildNumber':False,'stripSwiftSymbols':True,'uploadSymbols':True}
with open(pathlib.Path(env['RUNNER_TEMP'])/'ExportOptions.plist','wb') as output:plistlib.dump(options,output)
print('Configured existing App Store app:',app['attributes']['name'],'('+app['id']+')')
print('Bundle identifier:',bundle)
for resource in ['certificates','bundleIds','profiles']:
    diagnostic=urllib.request.Request('https://api.appstoreconnect.apple.com/v1/'+resource+'?limit=1',headers={'Authorization':'Bearer '+token})
    try:
        with urllib.request.urlopen(diagnostic,timeout=30) as response:
            json.load(response)
        print('Provisioning API access:',resource,'available')
    except urllib.error.HTTPError as error:
        details=json.loads(error.read())
        reasons=[item.get('detail',item.get('title','Denied')) for item in details.get('errors',[])]
        print('Provisioning API access:',resource,'HTTP',error.code,'; '.join(reasons))
print('Signing configuration ready. The workflow uploads only after exported signatures and capabilities pass verification; App Review submission is separate.')
def api_get(path):
    request=urllib.request.Request('https://api.appstoreconnect.apple.com/v1/'+path,headers={'Authorization':'Bearer '+token})
    try:
        with urllib.request.urlopen(request,timeout=30) as response:return json.load(response)
    except urllib.error.HTTPError as error:
        details=json.loads(error.read())
        print('Provisioning inspection:',error.code,'; '.join(item.get('detail',item.get('title','Denied')) for item in details.get('errors',[])))
        return {'data':[]}
from cryptography import x509
from cryptography.x509.oid import NameOID
for cert in api_get('certificates?limit=200')['data']:
    content=cert['attributes'].get('certificateContent')
    if content:
        parsed=x509.load_der_x509_certificate(base64.b64decode(content))
        units=parsed.subject.get_attributes_for_oid(NameOID.ORGANIZATIONAL_UNIT_NAME)
        print('Certificate team matches configured team:',any(unit.value==env['APPLE_TEAM_ID'] for unit in units))
for registered in api_get('bundleIds?limit=200')['data']:
    if registered['attributes']['identifier'] in [bundle,bundle+'.widget']:
        capabilities=api_get('bundleIds/'+registered['id']+'/bundleIdCapabilities')['data']
        print('Registered identifier:',registered['attributes']['identifier'],'capabilities:',','.join(item['attributes']['capabilityType'] for item in capabilities))
for profile in api_get('profiles?limit=200')['data']:
    import subprocess
    profile_path=pathlib.Path(env['RUNNER_TEMP'])/'inspect.mobileprovision'
    profile_path.write_bytes(base64.b64decode(profile['attributes']['profileContent']))
    decoded=subprocess.run(['security','cms','-D','-i',str(profile_path)],capture_output=True,check=True).stdout
    entitlements=plistlib.loads(decoded).get('Entitlements',{})
    identifier=entitlements.get('application-identifier','')
    if identifier.endswith('.'+bundle) or identifier.endswith('.'+bundle+'.widget'):
        print('Existing profile:',profile['attributes']['name'],'type:',profile['attributes']['profileType'],'groups:',entitlements.get('com.apple.security.application-groups',[]))
    profile_path.unlink()
