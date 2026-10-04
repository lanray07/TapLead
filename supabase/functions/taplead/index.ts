import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import { Buffer } from 'node:buffer';
import { cardSchema,leadSchema,captureSchema,publicCard,vcard,cardCSS } from './domain.js';
import { normaliseImage } from './media.ts';

const url=Deno.env.get('SUPABASE_URL')!;
const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const db=createClient(url,service,{auth:{autoRefreshToken:false,persistSession:false}});
const products=['com.taplead.pro.monthly','com.taplead.pro.yearly'];
const origin='https://lanray07.github.io';
const uuid=z.uuid().transform(s=>s.toLowerCase());
const sources=['qr','nfc','email','website','event','social','direct'];
const headers={'Access-Control-Allow-Origin':origin,'Access-Control-Allow-Methods':'GET,POST,PUT,DELETE,OPTIONS','Access-Control-Allow-Headers':'Content-Type,Authorization','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer'};
class HTTPError extends Error {constructor(public status:number,message:string){super(message);}}
function json(body:unknown,status=200){return new Response(JSON.stringify(body),{status,headers:{...headers,'Content-Type':'application/json'}});}
function check<T>(result:{data:T;error:unknown}):T {
  if(result.error){const error=result.error as {code?:string};const code=Number(error.code?.match(/^PT(\d{3})$/)?.[1]);throw new HTTPError(code||500,code===403?'Your plan does not allow this action.':code===404?'Record unavailable.':code===400?'Check the supplied details.':'Unable to complete this request.');}
  return result.data;
}
async function hash(value:string){return Buffer.from(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value))).toString('hex');}
async function body(req:Request,max=128*1024):Promise<Uint8Array> {
  if(Number(req.headers.get('content-length'))>max)throw new HTTPError(413,'The upload is too large.');
  const reader=req.body?.getReader();if(!reader)return new Uint8Array();
  const chunks:Uint8Array[]=[];let size=0;
  while(true){const part=await reader.read();if(part.done)break;size+=part.value.length;if(size>max){await reader.cancel();throw new HTTPError(413,'The upload is too large.');}chunks.push(part.value);}
  const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}return bytes;
}
async function input(req:Request):Promise<unknown> {try{return JSON.parse(new TextDecoder().decode(await body(req)));}catch(e){if(e instanceof HTTPError)throw e;throw new HTTPError(400,'Invalid JSON.');}}
async function rate(req:Request,scope:string,limit:number,seconds:number) {
  // Only a one-way IP digest is persisted, and expired buckets are removed on each request.
  const ip=req.headers.get('x-forwarded-for')?.split(',')[0].trim()||'unknown';
  const allowed=check(await db.rpc('taplead_rate',{p_key:await hash(scope+':'+ip),p_limit:limit,p_seconds:seconds}));
  if(!allowed)throw new HTTPError(429,'Too many requests. Try again later.');
}
async function authenticate(req:Request) {
  const token=req.headers.get('authorization')?.match(/^Bearer ([a-zA-Z0-9_-]{43})$/)?.[1];
  if(!token)throw new HTTPError(401,'Sign in again to continue.');
  const digest=await hash(token);
  const session=check(await db.from('taplead_sessions').select('owner').eq('hash',digest).gt('expires',new Date().toISOString()).maybeSingle());
  if(!session)throw new HTTPError(401,'Sign in again to continue.');return {owner:session.owner as string,digest};
}
async function issue(owner:string) {
  const token=Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString('base64url');
  check(await db.from('taplead_sessions').delete().lt('expires',new Date().toISOString()));
  check(await db.from('taplead_sessions').insert({hash:await hash(token),owner,expires:new Date(Date.now()+30*86400000).toISOString()}));
  return {token,userID:owner};
}
async function plan(owner:string){return {...check(await db.rpc('taplead_plan',{p_owner:owner})),purchasesEnabled:false,products};}
async function all(table:string,owner:string):Promise<Record<string,unknown>[]> {
  const rows:Record<string,unknown>[]=[];
  for(let offset=0;;offset+=500){const page=check(await db.from(table).select('*').eq('owner',owner).order('id').range(offset,offset+499))||[];rows.push(...page);if(page.length<500)return rows;}
}
async function cards(owner:string) {
  const records=await all('taplead_cards',owner);
  return Promise.all(records.map(async row=>{
    const card=row.data as Record<string,unknown>;
    if(card.cornerImageKind==='None')return card;
    const media=check(await db.from('taplead_media').select('kind,pixels').eq('card_id',row.id).eq('kind',String(card.cornerImageKind||'Photo')).maybeSingle());
    return media?{...card,[media.kind==='Logo'?'logoData':'photoData']:media.pixels}:card;
  }));
}
async function live(id:string) {
  const row=check(await db.from('taplead_cards').select('*').eq('id',id).maybeSingle());
  if(!row||!row.data.published)throw new HTTPError(404,'This profile is private or no longer available.');return row;
}
async function event(row:{id:string;data:{analyticsEnabled?:boolean}},kind:string,source:string) {
  if(row.data.analyticsEnabled)check(await db.from('taplead_events').insert({card_id:row.id,kind,source,created:Date.now()}));
}
async function handle(req:Request):Promise<Response> {
  if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
  const requestURL=new URL(req.url),path=requestURL.pathname.replace(/^\/taplead\/?/,'/').replace(/^\/functions\/v1\/taplead\/?/,'/');
  const method=req.method,source=sources.includes(requestURL.searchParams.get('source')||'')?requestURL.searchParams.get('source')!:'direct';
  await rate(req,'global',120,60);
  if(path==='/health'&&method==='GET')return json({ok:true,service:'TapLead',purchasesEnabled:false});
  if(['/api/auth/register','/api/auth/login','/api/auth/recover'].includes(path))throw new HTTPError(410,'Email accounts are no longer available. Continue with Apple or use guest mode on your iPhone.');
  if(path==='/api/auth/apple/challenge'||path==='/api/auth/apple')throw new HTTPError(503,'Apple sign-in is awaiting its production credential configuration.');
  const profile=path.match(/^\/p\/([^/]+)(?:\/(.*))?$/);
  if(profile) {
    const id=uuid.parse(profile[1]),tail=profile[2]||'',row=await live(id);
    if(method==='GET'&&!tail){const media=row.data.cornerImageKind!=='None'&&check(await db.from('taplead_media').select('card_id').eq('card_id',id).eq('kind',row.data.cornerImageKind||'Photo').maybeSingle());await event(row,'profile_view',source);return json(publicCard({...row.data,publicImageAvailable:Boolean(media)}));}
    if(method==='GET'&&tail==='theme.css')return new Response(cardCSS(row.data),{headers:{...headers,'Content-Type':'text/css'}});
    if(method==='GET'&&tail==='image') {
      if(row.data.cornerImageKind==='None')throw new HTTPError(404,'Image unavailable.');
      const media=check(await db.from('taplead_media').select('pixels').eq('card_id',id).eq('kind',row.data.cornerImageKind||'Photo').maybeSingle());
      if(!media)throw new HTTPError(404,'Image unavailable.');return new Response(Buffer.from(media.pixels,'base64'),{headers:{...headers,'Content-Type':'image/png','Content-Disposition':'inline; filename="card-image.png"'}});
    }
    if(method==='GET'&&tail==='contact.vcf'){await event(row,'vcard_download',source);return new Response(vcard(row.data),{headers:{...headers,'Content-Type':'text/vcard; charset=utf-8','Content-Disposition':'attachment; filename="contact.vcf"'}});}
    if(method==='GET'&&tail.startsWith('go/')) {
      const field=tail.slice(3);if(!['website','portfolio','booking','cv'].includes(field)||!row.data.publicFields.includes(field)||!row.data[field])throw new HTTPError(404,'Link unavailable.');
      await event(row,field==='booking'?'booking_click':'cta_click',source);return new Response(null,{status:303,headers:{...headers,Location:row.data[field]}});
    }
    if(method==='POST'&&tail==='leads') {
      await rate(req,'capture',5,3600);const c=captureSchema.parse(await input(req));
      const date=Date.now()/1000-978307200;
      const lead=leadSchema.parse({...c,id:crypto.randomUUID(),cardID:id,metAt:date,status:'New',notes:'',timeline:[{id:crypto.randomUUID(),date,kind:'received',text:'Details voluntarily shared through the public profile.'}]});
      check(await db.rpc('taplead_capture',{p_card:id,p_data:lead}));await event(row,'lead_submission',c.source);return json({message:'Your details have been shared. The card owner can now follow up with you.'},201);
    }
    throw new HTTPError(404,'Page unavailable.');
  }
  // No owner-scoped route can run before a live, revocable session check.
  const {owner,digest}=await authenticate(req);
  if(method==='POST'&&path==='/api/auth/logout'){check(await db.from('taplead_sessions').delete().eq('hash',digest).eq('owner',owner));return new Response(null,{status:204,headers});}
  if(method==='GET'&&path==='/api/plan')return json(await plan(owner));
  if(method==='POST'&&path==='/api/subscription')throw new HTTPError(503,'Purchases are not enabled until production receipt verification is configured.');
  if(method==='GET'&&path==='/api/cards')return json(await cards(owner));
  if(method==='GET'&&path==='/api/leads')return json((await all('taplead_leads',owner)).map(row=>row.data));
  const record=path.match(/^\/api\/(cards|leads)\/([^/]+)(?:\/(image))?$/);
  if(record) {
    const kind=record[1]==='cards'?'card':'lead',id=uuid.parse(record[2]),table='taplead_'+record[1];
    if(record[3]) {
      const card=check(await db.from('taplead_cards').select('data').eq('id',id).eq('owner',owner).maybeSingle());
      if(!card)throw new HTTPError(404,'Card not found.');
      if(method==='DELETE'){check(await db.rpc('taplead_image',{p_owner:owner,p_card:id,p_kind:null,p_pixels:null}));return new Response(null,{status:204,headers});}
      if(method==='PUT') {
        await rate(req,'image',20,3600);const imageKind=z.enum(['Photo','Logo']).parse(requestURL.searchParams.get('kind'));
        if(card.data.cornerImageKind!==imageKind)throw new HTTPError(409,'Update the card image choice before uploading.');
        let pixels:Uint8Array;try{pixels=await normaliseImage(await body(req,2*1024*1024),req.headers.get('content-type')?.split(';')[0]||'');}catch(e){if(e instanceof HTTPError)throw e;throw new HTTPError(400,'Choose a valid PNG or JPEG smaller than 2 MB.');}
        check(await db.rpc('taplead_image',{p_owner:owner,p_card:id,p_kind:imageKind,p_pixels:Buffer.from(pixels).toString('base64')}));return new Response(null,{status:204,headers});
      }
    } else {
      if(method==='PUT'){const data=(kind==='card'?cardSchema:leadSchema).parse(await input(req));if(data.id!==id)throw new HTTPError(400,'Record ID mismatch.');return json(check(await db.rpc('taplead_save',{p_owner:owner,p_kind:kind,p_data:data})));}
      if(method==='DELETE'){check(await db.from(table).delete().eq('id',id).eq('owner',owner));return new Response(null,{status:204,headers});}
    }
  }
  if(method==='GET'&&path==='/api/analytics') {
    if(!(await plan(owner)).pro)throw new HTTPError(403,'Activity insights require a verified Pro subscription.');
    const days=Number(requestURL.searchParams.get('days')||30);if(![7,30,90,0].includes(days))throw new HTTPError(400,'Unsupported date range.');
    const owned=await all('taplead_cards',owner),ids=owned.map(row=>row.id),events:unknown[]=[];
    if(ids.length)for(let offset=0;;offset+=500){const page=check(await db.from('taplead_events').select('kind,source,created').in('card_id',ids).gte('created',days?Date.now()-days*86400000:0).order('id').range(offset,offset+499))||[];events.push(...page);if(page.length<500)break;}
    return json({events,notice:'Views are requests, not unique people. vCard downloads do not confirm a contact was saved. NFC source is link attribution only.'});
  }
  if(method==='POST'&&path==='/api/ai')throw new HTTPError(503,'Use on-device AI on a supported iPhone. Your notes have not been sent to an external AI provider.');
  if(method==='GET'&&path==='/api/export')return json({cards:await cards(owner),leads:(await all('taplead_leads',owner)).map(row=>row.data)});
  if(method==='DELETE'&&path==='/api/account') {
    const user=await db.auth.admin.getUserById(owner);
    if(user.error||!user.data.user)throw new HTTPError(401,'Sign in again to continue.');
    if(user.data.user.identities?.some(identity=>identity.provider==='apple'))throw new HTTPError(503,'Apple grant revocation must complete before deleting this account.');
    const result=await db.auth.admin.deleteUser(owner);if(result.error)throw new HTTPError(503,'Account deletion is temporarily unavailable. Please retry.');
    return new Response(null,{status:204,headers});
  }
  throw new HTTPError(404,'Endpoint unavailable.');
}
Deno.serve(async req=>{try{return await handle(req);}catch(error){if(error instanceof HTTPError)return json({error:error.message},error.status);if(error instanceof z.ZodError)return json({error:'Invalid input. Check the fields and try again.'},400);console.error('Request failed',error instanceof Error?error.name:'Unknown');return json({error:'Unable to complete this request. Please try again.'},500);}});
