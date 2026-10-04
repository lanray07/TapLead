import express from 'express';
import helmet from 'helmet';
import { randomUUID, randomBytes, createHash, scryptSync, timingSafeEqual } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { z } from 'zod';
import { cardSchema, leadSchema, captureSchema, vcard } from './domain.js';
import { profileHTML, messageHTML } from './public.js';
import {planFor,storeTransaction,proProducts} from './subscriptions.js';

const appleKeys=createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));
const hash=v=>createHash('sha256').update(v).digest('hex');
const now=()=>Date.now();
// Swift's default Codable Date uses seconds since 2001-01-01.
const swiftDate=()=>Date.now()/1000-978307200;
const sourceOf=req=>['qr','nfc','email','website','event','social','direct'].includes(req.query.source)?req.query.source:'direct';
const credentials=z.object({email:z.email().max(254).transform(s=>s.toLowerCase()),password:z.string().min(12).max(256)});
export function createApp(db,config={}) {
  const app=express(); app.disable('x-powered-by');
  app.use(helmet({contentSecurityPolicy:{directives:{defaultSrc:["'none'"],styleSrc:["'self'"],imgSrc:["'self'"],formAction:["'self'"],baseUri:["'none'"],frameAncestors:["'none'"]}}}));
  app.use(express.json({limit:'128kb'}),express.urlencoded({extended:false,limit:'16kb'}));
  app.use('/assets',express.static(fileURLToPath(new URL('../public',import.meta.url)),{maxAge:'1h'}));
  const buckets=new Map();
  const limiter=(limit,window)=> { const scope=randomUUID(); return (req,res,next)=> {
    const key=`${scope}:${req.ip}`, ts=now();
    if(buckets.size>10000) for(const [k,b] of buckets) if(b.until<=ts)buckets.delete(k);
    const b=buckets.get(key)||{count:0,until:ts+window};if(b.until<=ts){b.count=0;b.until=ts+window;}b.count++;buckets.set(key,b);
    if(b.count>limit)return res.status(429).json({error:'Too many requests. Try again later.'});next();
  }; };
  app.use(limiter(120,60000));
  const auth=(req,res,next)=> {
    const token=req.headers.authorization?.match(/^Bearer ([a-zA-Z0-9_-]+)$/)?.[1];
    const session=token&&db.prepare('SELECT user_id FROM sessions WHERE hash=? AND expires>?').get(hash(token),now());
    if(!session)return res.status(401).json({error:'Sign in again to continue.'});req.owner=session.user_id;next();
  };
  const issue=owner=> {
    const token=randomBytes(32).toString('base64url');db.prepare('DELETE FROM sessions WHERE expires<=?').run(now());
    db.prepare('INSERT INTO sessions VALUES(?,?,?)').run(hash(token),owner,now()+30*86400000);return {token,userID:owner};
  };
  const ownedCard=(id,owner)=>db.prepare('SELECT * FROM cards WHERE id=? AND owner=?').get(id,owner);
  const liveCard=id=>{const row=db.prepare('SELECT * FROM cards WHERE id=?').get(id);if(!row)return null;const card=JSON.parse(row.data);return card.published?{...row,card}:null;};
  const event=(row,kind,source)=>{if(row.card.analyticsEnabled) db.prepare('INSERT INTO events(card_id,kind,source,created) VALUES(?,?,?,?)').run(row.id,kind,source,now());};
  app.get('/health',(_req,res)=>res.json({ok:true}));
  app.get('/',(_req,res)=>res.type('html').send(messageHTML('TapLead','Tap. Connect. Convert. Open a shared TapLead link to connect.')));
  app.post('/api/auth/register',limiter(5,3600000),(req,res)=>{
    const c=credentials.parse(req.body),salt=randomBytes(16).toString('hex'),pass=scryptSync(c.password,salt,64).toString('hex'),id=randomUUID();
    if(db.prepare('SELECT id FROM users WHERE email=?').get(c.email))return res.status(409).json({error:'Unable to create account. Try signing in.'});
    db.prepare('INSERT INTO users VALUES(?,?,?,?,?)').run(id,c.email,`${salt}:${pass}`,null,now());res.status(201).json(issue(id));
  });
  app.post('/api/auth/login',limiter(10,900000),(req,res)=>{
    const c=credentials.parse(req.body),u=db.prepare('SELECT * FROM users WHERE email=?').get(c.email),[salt,stored]=(u?.password||'00000000000000000000000000000000:'+ '00'.repeat(64)).split(':');
    const matches=timingSafeEqual(scryptSync(c.password,salt,64),Buffer.from(stored,'hex'));
    if(!u?.password||!matches)return res.status(401).json({error:'Email or password is incorrect.'});res.json(issue(u.id));
  });
  app.post('/api/auth/apple/challenge',limiter(10,900000),(_req,res)=>{const nonce=randomBytes(32).toString('hex');db.prepare('DELETE FROM challenges WHERE expires<=?').run(now());db.prepare('INSERT INTO challenges VALUES(?,?)').run(nonce,now()+300000);res.json({nonce});});
  app.post('/api/auth/apple',limiter(10,900000),async(req,res)=>{
    if(!config.appleClientID||!config.appleAuth)return res.status(503).json({error:'Apple sign-in and account deletion credentials are not configured.'});
    const {identityToken,nonce,authorizationCode}=z.object({identityToken:z.string().max(10000),nonce:z.string().length(64),authorizationCode:z.string().min(1).max(4000)}).parse(req.body);
    const challenge=db.prepare('SELECT nonce FROM challenges WHERE nonce=? AND expires>?').get(nonce,now());
    if(!challenge)return res.status(401).json({error:'Sign-in challenge expired.'});
    const {payload}=await jwtVerify(identityToken,appleKeys,{issuer:'https://appleid.apple.com',audience:config.appleClientID,algorithms:['RS256']});
    if(payload.nonce!==hash(nonce)||!payload.sub)return res.status(401).json({error:'Invalid Apple sign-in challenge.'});
    const exchanged=await config.appleAuth.exchange(authorizationCode);
    const verified=await jwtVerify(exchanged.identityToken,appleKeys,{issuer:'https://appleid.apple.com',audience:config.appleClientID,algorithms:['RS256']});
    if(verified.payload.sub!==payload.sub)return res.status(401).json({error:'Apple authorization did not match this account.'});
    db.prepare('DELETE FROM challenges WHERE nonce=?').run(nonce);
    let u=db.prepare('SELECT id FROM users WHERE apple_sub=?').get(payload.sub);
    if(!u){u={id:randomUUID()};db.prepare('INSERT INTO users VALUES(?,?,?,?,?)').run(u.id,null,null,payload.sub,now());}
    db.prepare('INSERT INTO apple_credentials VALUES(?,?) ON CONFLICT(user_id) DO UPDATE SET sealed_refresh=excluded.sealed_refresh').run(u.id,exchanged.sealed);res.json(issue(u.id));
  });
  app.post('/api/auth/logout',auth,(req,res)=>{db.prepare('DELETE FROM sessions WHERE hash=?').run(hash(req.headers.authorization.slice(7)));res.status(204).end();});
  app.get('/api/plan',auth,(req,res)=>res.json({...planFor(db,req.owner),purchasesEnabled:Boolean(config.subscriptionVerifier&&config.subscriptionsEnabled),products:proProducts}));
  app.post('/api/subscription',auth,async(req,res)=>{
    if(!config.subscriptionVerifier||!config.subscriptionsEnabled)return res.status(503).json({error:'Purchases are not enabled for this release.'});
    const {signedTransaction}=z.object({signedTransaction:z.string().min(1).max(30000)}).parse(req.body);
    try {const transaction=await config.subscriptionVerifier.verifyAndDecodeTransaction(signedTransaction);res.json(storeTransaction(db,transaction,req.owner));}
    catch{return res.status(400).json({error:'This subscription could not be verified for your account.'});}
  });
  app.post('/api/apple/notifications',async(req,res)=>{
    if(!config.subscriptionVerifier)return res.sendStatus(503);
    const {signedPayload}=z.object({signedPayload:z.string().max(60000)}).parse(req.body);
    try {const notification=await config.subscriptionVerifier.verifyAndDecodeNotification(signedPayload);const signed=notification.data?.signedTransactionInfo;if(signed){const transaction=await config.subscriptionVerifier.verifyAndDecodeTransaction(signed);const owner=transaction.appAccountToken?.toLowerCase();if(owner&&db.prepare('SELECT id FROM users WHERE id=?').get(owner))storeTransaction(db,transaction,owner);}res.status(200).json({ok:true});}
    catch{return res.status(400).json({error:'Invalid Apple notification.'});}
  });
  app.get('/api/cards',auth,(req,res)=>res.json(db.prepare('SELECT data FROM cards WHERE owner=?').all(req.owner).map(r=>JSON.parse(r.data))));
  app.put('/api/cards/:id',auth,(req,res)=>{
    const c=cardSchema.parse(req.body);if(c.id!==req.params.id)return res.status(400).json({error:'Card ID mismatch.'});
    const existing=db.prepare('SELECT owner FROM cards WHERE id=?').get(c.id);if(existing&&existing.owner!==req.owner)return res.status(404).json({error:'Card not found.'});
    // Server-side free allowance. Pro expansion requires verified App Store transactions.
    if(!existing&&db.prepare('SELECT count(*) n FROM cards WHERE owner=?').get(req.owner).n>=planFor(db,req.owner).cardLimit)return res.status(403).json({error:'Your plan card limit has been reached.'});
    db.prepare('INSERT INTO cards VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data').run(c.id,req.owner,JSON.stringify(c));res.json(c);
  });
  app.delete('/api/cards/:id',auth,(req,res)=>{db.prepare('DELETE FROM cards WHERE id=? AND owner=?').run(req.params.id,req.owner);res.status(204).end();});
  app.get('/api/leads',auth,(req,res)=>res.json(db.prepare('SELECT data FROM leads WHERE owner=?').all(req.owner).map(r=>JSON.parse(r.data))));
  app.put('/api/leads/:id',auth,(req,res)=>{
    const l=leadSchema.parse(req.body);if(l.id!==req.params.id)return res.status(400).json({error:'Lead ID mismatch.'});
    if(l.cardID&&!ownedCard(l.cardID,req.owner))return res.status(400).json({error:'Select a card you own.'});
    const existing=db.prepare('SELECT owner FROM leads WHERE id=?').get(l.id);if(existing&&existing.owner!==req.owner)return res.status(404).json({error:'Lead not found.'});
    if(!existing&&db.prepare('SELECT count(*) n FROM leads WHERE owner=?').get(req.owner).n>=planFor(db,req.owner).leadLimit)return res.status(403).json({error:'Your plan lead limit has been reached.'});
    db.prepare('INSERT INTO leads VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data').run(l.id,req.owner,JSON.stringify(l));res.json(l);
  });
  app.delete('/api/leads/:id',auth,(req,res)=>{db.prepare('DELETE FROM leads WHERE id=? AND owner=?').run(req.params.id,req.owner);res.status(204).end();});
  app.get('/p/:id',(req,res)=>{const r=liveCard(req.params.id);if(!r)return res.status(404).type('html').send(messageHTML('Card unavailable','This profile is private or no longer available.'));event(r,'profile_view',sourceOf(req));res.set('Cache-Control','no-store').type('html').send(profileHTML(r.card,sourceOf(req),config.privacyURL));});
  app.get('/p/:id/contact.vcf',(req,res)=>{const r=liveCard(req.params.id);if(!r)return res.sendStatus(404);event(r,'vcard_download',sourceOf(req));res.set({'Content-Type':'text/vcard; charset=utf-8','Content-Disposition':'attachment; filename="contact.vcf"','Cache-Control':'no-store'}).send(vcard(r.card));});
  app.get('/p/:id/go/:kind',(req,res)=>{const r=liveCard(req.params.id);if(!r)return res.sendStatus(404);const k=req.params.kind;if(!['website','portfolio','booking'].includes(k)||!r.card.publicFields.includes(k)||!r.card[k])return res.sendStatus(404);event(r,k==='booking'?'booking_click':'cta_click',sourceOf(req));res.redirect(303,r.card[k]);});
  app.post('/p/:id/leads',limiter(5,3600000),(req,res)=>{
    const r=liveCard(req.params.id);if(!r)return res.sendStatus(404);
    const parsed=captureSchema.safeParse({...req.body,consent:req.body.consent===true||req.body.consent==='true'});
    if(!parsed.success)return res.status(400).type('html').send(messageHTML('Check your details','Enter your name, a valid email or phone number, and consent to sharing.'));
    if(db.prepare('SELECT count(*) n FROM leads WHERE owner=?').get(r.owner).n>=planFor(db,r.owner).leadLimit)return res.status(409).type('html').send(messageHTML('Inbox currently full','Please use the contact links on this profile instead.'));
    const c=parsed.data,id=randomUUID(),l=leadSchema.parse({...c,id,cardID:r.id,metAt:swiftDate(),status:'New',notes:'',timeline:[{id:randomUUID(),date:swiftDate(),kind:'received',text:'Details voluntarily shared through the public profile.'}]});
    db.prepare('INSERT INTO leads VALUES(?,?,?)').run(id,r.owner,JSON.stringify(l));event(r,'lead_submission',c.source);
    res.status(201).type('html').send(messageHTML('You’re connected','Your details have been shared. The card owner can now follow up with you.'));
  });
  app.get('/api/analytics',auth,(req,res)=>{
    const days=Number(req.query.days||30);if(![7,30,90,0].includes(days))return res.status(400).json({error:'Unsupported date range.'});
    const rows=db.prepare('SELECT e.kind,e.source,e.created FROM events e JOIN cards c ON c.id=e.card_id WHERE c.owner=? AND e.created>=?').all(req.owner,days?now()-days*86400000:0);
    res.json({events:rows,notice:'Views are requests, not unique people. vCard downloads do not confirm a contact was saved. NFC source is link attribution only.'});
  });
  app.post('/api/ai',auth,limiter(20,3600000),async(req,res)=>{
    const input=z.object({consent:z.literal(true),kind:z.enum(['smart_notes','follow_up']),notes:z.string().min(1).max(12000),name:textName(),tone:z.enum(['Friendly','Professional','Concise','Sales','Casual']),channel:z.enum(['Email','SMS','LinkedIn','WhatsApp'])}).parse(req.body);
    if(!config.aiURL||!config.aiToken)return res.status(503).json({error:'AI processing is not configured. Your notes have not been sent to an AI provider.'});
    const response=await fetch(config.aiURL,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${config.aiToken}`},body:JSON.stringify({...input,instructions:'Use only supplied facts. Missing fields must be null. Suggestions must be labelled. Return a draft, never send a message.'}),signal:AbortSignal.timeout(30000)});
    if(!response.ok)throw new Error('AI gateway unavailable');
    const output=z.object({draft:z.string().max(12000).nullable(),facts:z.array(z.object({field:z.string().max(100),value:z.string().max(2000),evidence:z.string().min(1).max(2000)})).max(20),suggestions:z.array(z.string().max(2000)).max(10)}).parse(await response.json());
    if(output.facts.some(f=>!input.notes.includes(f.evidence)))throw new Error('AI evidence validation failed');res.json(output);
  });
  app.get('/api/export',auth,(req,res)=>res.json({cards:db.prepare('SELECT data FROM cards WHERE owner=?').all(req.owner).map(r=>JSON.parse(r.data)),leads:db.prepare('SELECT data FROM leads WHERE owner=?').all(req.owner).map(r=>JSON.parse(r.data))}));
  app.delete('/api/account',auth,async(req,res)=>{const u=db.prepare('SELECT apple_sub FROM users WHERE id=?').get(req.owner);if(u.apple_sub){const credentials=db.prepare('SELECT sealed_refresh FROM apple_credentials WHERE user_id=?').get(req.owner);if(!config.appleAuth||!credentials)return res.status(503).json({error:'Apple revocation is temporarily unavailable. Your data is preserved; please retry.'});await config.appleAuth.revoke(credentials.sealed_refresh);}db.prepare('DELETE FROM users WHERE id=?').run(req.owner);res.status(204).end();});
  app.use((err,req,res,_next)=>{if(err instanceof z.ZodError)return res.status(400).json({error:'Invalid input. Check the fields and try again.'});if(err?.code?.startsWith('ERR_J'))return res.status(401).json({error:'Apple sign-in could not be verified.'});console.error('Request failed:',err.name);res.status(500).json({error:'Unable to complete this request. Please try again.'});});
  return app;
}
function textName(){return z.string().max(120);}
