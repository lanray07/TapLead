"""Exercise the deployed API using disposable, explicitly synthetic Free fixtures.

prepare writes a private ignored token file and a SQL seed for the project owner.
test exercises HTTPS routes. cleanup deletes only the two fixture accounts via the
normal authenticated API. Never use this as evidence of email/Apple/StoreKit auth.
"""
import argparse, base64, hashlib, json, pathlib, secrets, urllib.error, urllib.request, uuid

ROOT=pathlib.Path(__file__).resolve().parents[1]
DIR=ROOT/'artifacts/cloud-smoke'
API='https://qyflrgvolsiljpsghqku.supabase.co/functions/v1/taplead'
parser=argparse.ArgumentParser()
parser.add_argument('mode',choices=['prepare','test','cleanup'])
args=parser.parse_args()

def request(path,method='GET',data=None,token=None,mime='application/json'):
    headers={'Content-Type':mime}
    if token:headers['Authorization']='Bearer '+token
    if data is not None and not isinstance(data,bytes):data=json.dumps(data).encode()
    req=urllib.request.Request(API+'/'+path,data=data,method=method,headers=headers)
    try:
        with urllib.request.urlopen(req,timeout=35) as response:return response.status,response.read()
    except urllib.error.HTTPError as error:return error.code,error.read()

def expect(status,result,label):
    assert result[0]==status, f'{label}: expected HTTP {status}, received {result[0]}'
    return result[1]

if args.mode=='prepare':
    DIR.mkdir(parents=True,exist_ok=True)
    if (DIR/'private.json').exists():raise SystemExit('Existing fixture must be cleaned up before preparing another.')
    fixture={'a':str(uuid.uuid4()),'b':str(uuid.uuid4()),'card':str(uuid.uuid4()),'tokenA':secrets.token_urlsafe(32),'tokenB':secrets.token_urlsafe(32)}
    (DIR/'private.json').write_text(json.dumps(fixture),encoding='utf-8')
    statements=[]
    for owner,token in [('a','tokenA'),('b','tokenB')]:
        uid=fixture[owner];digest=hashlib.sha256(fixture[token].encode()).hexdigest()
        # GoTrue's model expects empty strings for these optional tokens, and its
        # singleton instance ID, even though SQL permits NULLs. These are disposable
        # unverified identities with no usable password, not a signup acceptance test.
        statements.append(f"insert into auth.users(id,instance_id,aud,role,email,encrypted_password,confirmation_token,recovery_token,email_change_token_new,email_change,email_change_token_current,phone_change,phone_change_token,reauthentication_token,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values('{uid}','00000000-0000-0000-0000-000000000000','authenticated','authenticated','cloud-fixture-{uid}@example.invalid','','','','','','','','','', '{{\"provider\":\"email\",\"providers\":[\"email\"]}}','{{}}',now(),now());")
        statements.append(f"insert into public.taplead_sessions(hash,owner,expires) values('{digest}','{uid}',now()+interval '1 hour');")
    (DIR/'seed.sql').write_text('begin;\n'+'\n'.join(statements)+'\ncommit;',encoding='utf-8')
    print('Prepared two disposable Free fixtures; no tokens printed.')
else:
    f=json.loads((DIR/'private.json').read_text(encoding='utf-8'))
    if args.mode=='cleanup':
        for key in ['tokenA','tokenB']:
            if key in f.get('cleaned',[]):continue
            expect(204,request('api/account','DELETE',token=f[key]),'fixture account cleanup')
            expect(401,request('api/cards',token=f[key]),'deleted account session revoked')
            f.setdefault('cleaned',[]).append(key)
            (DIR/'private.json').write_text(json.dumps(f),encoding='utf-8')
        expect(404,request('p/'+f['card']),'deleted public profile unavailable')
        (DIR/'private.json').unlink()
        print('Deleted both disposable accounts through the API; cascades and session revocation passed.')
    else:
        a,b=f['tokenA'],f['tokenB'];cid=f['card']
        expect(401,request('api/cards'),'anonymous private access')
        plan=json.loads(expect(200,request('api/plan',token=a),'Free plan'))
        assert not plan['pro'] and plan['cardLimit']==1 and plan['leadLimit']==50 and isinstance(plan['purchasesEnabled'],bool)
        card={'id':cid,'name':'Demo — Taylor Reed','preferredName':'Taylor','title':'Product designer','company':'Fictional cloud test','persona':'Test sample','headline':'A clear introduction. A real connection.','bio':'An original fictional profile used to verify TapLead cloud publishing.','email':'taylor@example.invalid','phone':'','website':'https://example.com','booking':'https://example.com/private-booking','publicFields':['email','website'],'cornerImageKind':'Logo','cornerImagePosition':'Bottom right','published':True,'analyticsEnabled':True,'theme':'Executive','accent':'6654D9'}
        expect(200,request('api/cards/'+cid,'PUT',card,a),'publish owned Free card')
        expect(404,request('api/cards/'+cid,'PUT',card,b),'cross-owner overwrite')
        extra={**card,'id':str(uuid.uuid4())}
        expect(403,request('api/cards/'+extra['id'],'PUT',extra,a),'atomic card quota')
        expect(403,request('api/cards/'+cid,'PUT',{**card,'theme':'Elegant'},a),'Pro appearance gate')
        image=(ROOT/'iOS/UITests/Fixtures/corner-logo.png').read_bytes()
        expect(400,request('api/cards/'+cid+'/image?kind=Logo','PUT',image,a,'image/jpeg'),'spoofed image MIME')
        expect(204,request('api/cards/'+cid+'/image?kind=Logo','PUT',image,a,'image/png'),'portable image upload')
        public=json.loads(expect(200,request('p/'+cid+'?source=qr'),'public profile JSON'))
        assert 'booking' not in public and public['publicImageAvailable']
        expect(404,request('p/'+cid+'/go/booking'),'private CTA denial')
        expect(200,request('p/'+cid+'/image'),'public selected logo')
        contact=expect(200,request('p/'+cid+'/contact.vcf?source=qr'),'public vCard')
        assert b'BEGIN:VCARD' in contact and b'private-booking' not in contact
        capture={'name':'Fictional visitor','email':'visitor@example.invalid','consent':False,'source':'qr'}
        expect(400,request('p/'+cid+'/leads','POST',capture),'missing consent')
        expect(201,request('p/'+cid+'/leads','POST',{**capture,'consent':True}),'consented public capture')
        leads=json.loads(expect(200,request('api/leads',token=a),'cloud lead inbox'))
        assert len(leads)==1 and leads[0]['consent'] and leads[0]['cardID']==cid
        exported=json.loads(expect(200,request('api/export',token=a),'owned export'))
        assert len(exported['cards'])==1 and exported['cards'][0]['logoData']
        expect(403,request('api/analytics',token=a),'Free analytics gate')
        expect(400,request('api/subscription','POST',{'signedTransaction':'not-a-receipt'},a),'invalid signed receipt rejected')
        print('HTTPS ownership, quotas, privacy, portable image upload, vCard, consented capture, inbox/export and paid gates passed.')
        print('Browser proof URL: https://lanray07.github.io/TapLead/card/?id='+cid+'&source=qr')
