import {productionVerifier,sandboxVerifier,transactionRecord} from './subscriptions.ts';
import {SignJWT,generateKeyPair} from 'jose';
import {X509Certificate} from 'node:crypto';
import {Buffer} from 'node:buffer';
import roots from './apple-roots.json' with {type:'json'};
function assert(value:unknown){if(!value)throw new Error('Assertion failed');}
Deno.test('Bundled Apple roots have valid self signatures in the Edge crypto runtime',()=>{
  for(const root of roots){const certificate=new X509Certificate(Buffer.from(root,'base64'));assert(certificate.ca);assert(certificate.verify(certificate.publicKey));assert(Date.parse(certificate.validTo)>Date.now());}
});
Deno.test('Apple receipt verifier rejects unsigned and attacker-signed transactions',async()=>{
  const {privateKey}=await generateKeyPair('ES256');
  const forged=await new SignJWT({bundleId:'com.TapLead.app',environment:'Production'}).setProtectedHeader({alg:'ES256'}).sign(privateKey);
  for(const verifier of [productionVerifier,sandboxVerifier])for(const signed of ['invalid.synthetic.receipt',forged]){
    let rejected=false;try{await verifier.verifyAndDecodeTransaction(signed);}catch{rejected=true;}assert(rejected);
  }
});
Deno.test('Verified payload mapping binds owner and separates Sandbox from Production',()=>{
  const owner='00000000-0000-4000-8000-000000000001';
  const t={appAccountToken:owner,bundleId:'com.TapLead.app',productId:'com.taplead.pro.monthly',originalTransactionId:'1234',expiresDate:Date.now()+10000,signedDate:Date.now(),environment:'Sandbox',type:'Auto-Renewable Subscription'};
  assert(transactionRecord(t,owner).environment==='Sandbox');
  for(const bad of [{...t,appAccountToken:'00000000-0000-4000-8000-000000000002'},{...t,productId:'other.product'},{...t,bundleId:'other.app'},{...t,signedDate:NaN},{...t,environment:'Xcode'}]){
    let rejected=false;try{transactionRecord(bad,owner);}catch{rejected=true;}assert(rejected);
  }
});
