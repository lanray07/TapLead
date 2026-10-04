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
print('Signed artifact export only; no App Store upload or submission.')
