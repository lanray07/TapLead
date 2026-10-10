"""Update only TapLead's editable storefront metadata using existing runner secrets.
No build upload, review submission, credentials on disk, or purchase changes.
"""
import argparse,base64,json,os,time,urllib.request,urllib.error,urllib.parse
from pathlib import Path
from cryptography.hazmat.primitives import hashes,serialization
from cryptography.hazmat.primitives.asymmetric import ec,utils

BASE='https://api.appstoreconnect.apple.com'
APP='6818982306'
SUPPORT='https://github.com/lanray07/TapLead/blob/main/docs/SUPPORT.md'
PRIVACY='https://github.com/lanray07/TapLead/blob/main/docs/PRIVACY.md'
EULA='https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'
def token():
    pem=os.environ['APP_STORE_CONNECT_API_PRIVATE_KEY'].replace('\\n','\n').strip()
    if not pem.startswith('-----BEGIN'):pem=base64.b64decode(pem).decode()
    key=serialization.load_pem_private_key(pem.encode(),password=None)
    encode=lambda v:base64.urlsafe_b64encode(v).rstrip(b'=')
    h=encode(json.dumps({'alg':'ES256','kid':os.environ['APP_STORE_CONNECT_API_KEY_ID'],'typ':'JWT'},separators=(',',':')).encode())
    now=int(time.time());p=encode(json.dumps({'iss':os.environ['APP_STORE_CONNECT_ISSUER_ID'],'iat':now,'exp':now+600,'aud':'appstoreconnect-v1'},separators=(',',':')).encode())
    unsigned=h+b'.'+p;r,s=utils.decode_dss_signature(key.sign(unsigned,ec.ECDSA(hashes.SHA256())))
    return (unsigned+b'.'+encode(r.to_bytes(32,'big')+s.to_bytes(32,'big'))).decode()
def api(path,method='GET',data=None):
    assert path.startswith('/v1/'), 'Unexpected API destination'
    for attempt in range(4):
        req=urllib.request.Request(BASE+path,data=json.dumps(data).encode() if data else None,method=method,headers={'Authorization':'Bearer '+token(),'Content-Type':'application/json'})
        try:
            with urllib.request.urlopen(req,timeout=60) as r:return json.load(r) if r.status!=204 else {}
        except urllib.error.HTTPError as e:
            if e.code in [429,500,502,503,504] and attempt<3:time.sleep(2**attempt);continue
            details=json.loads(e.read()).get('errors',[])
            raise RuntimeError(f'{method} {path.split("?")[0]} HTTP {e.code}: '+ '; '.join(x.get('detail',x.get('title','Error')) for x in details)) from None
def listing(path):
    result=[]
    while path:
        response=api(path);result+=response['data'];n=response.get('links',{}).get('next');path=n.removeprefix(BASE) if n else None
    return result
def write(kind,attributes,existing=None,parent=None):
    data={'type':kind,'attributes':attributes}
    if existing:data['id']=existing;return api('/v1/'+kind+'/'+existing,'PATCH',{'data':data})['data']
    relation,parent_kind,parent_id=parent
    data['relationships']={relation:{'data':{'type':parent_kind,'id':parent_id}}}
    return api('/v1/'+kind,'POST',{'data':data})['data']

def main():
    parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['inspect','apply']);args=parser.parse_args()
    copy=json.loads(Path('marketing/store-localizations.json').read_text(encoding='utf-8'))
    assert len(copy)==50
    for locale,item in copy.items():
        assert len(item['subtitle'])<=30,locale
        assert len(item['keywords'].encode())<=100,locale
        assert len('TapLead — '+', '.join(item['captions'])+'.')<=170,locale
        assert not any(x in (item['description']+item['keywords']).lower() for x in ['nfc','unlimited','badge scan'])
    app=api('/v1/apps/'+APP)['data'];assert app['attributes']['bundleId']=='com.TapLead.app'
    infos=listing('/v1/apps/'+APP+'/appInfos?limit=200')
    versions=listing('/v1/apps/'+APP+'/appStoreVersions?filter[platform]=IOS&filter[versionString]=1.0.0&limit=200')
    editable={'PREPARE_FOR_SUBMISSION','REJECTED','METADATA_REJECTED','DEVELOPER_REJECTED'}
    candidates=[v for v in versions if v['attributes'].get('appStoreState') in editable]
    assert len(candidates)==1, 'Need one editable 1.0.0 iOS version'
    version=candidates[0]
    info_candidates=[v for v in infos if v['attributes'].get('appStoreState') in editable]
    assert len(info_candidates)==1,'Need one editable app information record'
    info=info_candidates[0]
    info_locs=listing('/v1/appInfos/'+info['id']+'/appInfoLocalizations?limit=200')
    version_locs=listing('/v1/appStoreVersions/'+version['id']+'/appStoreVersionLocalizations?limit=200')
    report={'app_id':APP,'version_id':version['id'],'info_id':info['id'],'version_state':version['attributes']['appStoreState'],'existing_info_locales':[v['attributes']['locale'] for v in info_locs],'existing_version_locales':[v['attributes']['locale'] for v in version_locs],'updated':[],'errors':[]}
    Path('artifacts/storefront').mkdir(parents=True,exist_ok=True)
    def save():Path('artifacts/storefront/metadata-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    save();print(json.dumps({k:v for k,v in report.items() if k not in ['updated','errors']}))
    if args.mode=='inspect':return
    info_map={v['attributes']['locale']:v['id'] for v in info_locs};version_map={v['attributes']['locale']:v['id'] for v in version_locs}
    for locale,item in copy.items():
        try:
            ia={'name':'TapLead','subtitle':item['subtitle'],'privacyPolicyUrl':PRIVACY}
            if locale not in info_map:ia['locale']=locale
            il=write('appInfoLocalizations',ia,info_map.get(locale),('appInfo','appInfos',info['id']))
            va={'description':item['description']+'\n\nTerms of Use (EULA): '+EULA+'\nPrivacy Policy: '+PRIVACY,'keywords':item['keywords'],'promotionalText':'TapLead — '+', '.join(item['captions'])+'.','supportUrl':SUPPORT,'marketingUrl':'https://github.com/lanray07/TapLead'}
            if locale not in version_map:va['locale']=locale
            vl=write('appStoreVersionLocalizations',va,version_map.get(locale),('appStoreVersion','appStoreVersions',version['id']))
            # Read back actual saved public metadata, not just a successful request.
            for kind,record,expected in [('appInfoLocalizations',il,ia),('appStoreVersionLocalizations',vl,va)]:
                actual=api('/v1/'+kind+'/'+record['id'])['data']['attributes']
                assert all(actual.get(k)==v for k,v in expected.items()),locale+' metadata read-back mismatch'
            report['updated'].append({'locale':locale,'info_localization_id':il['id'],'version_localization_id':vl['id']});print('Saved and verified:',locale,flush=True)
        except Exception as error:report['errors'].append({'locale':locale,'message':str(error)});print('Failed:',locale,str(error),flush=True)
        save()
    if report['errors']:raise SystemExit('Some locales need correction; successful metadata was preserved.')

if __name__=='__main__':main()
