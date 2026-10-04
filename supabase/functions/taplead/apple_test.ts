import {sealRefresh,openRefresh,nonceHash} from './apple.ts';
function assert(value:unknown){if(!value)throw new Error('Assertion failed');}
Deno.test('Apple nonce hashing matches the native SHA256 protocol',async()=>{
  assert(await nonceHash('abc')==='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
});
Deno.test('Apple refresh credentials are encrypted and bound to their Apple subject',async()=>{
  const key=crypto.getRandomValues(new Uint8Array(32)),token='synthetic-refresh-token';
  const sealed=await sealRefresh(token,key,'owner-a');
  assert(!sealed.includes(token));assert(sealed!==await sealRefresh(token,key,'owner-a'));
  assert(await openRefresh(sealed,key,'owner-a')===token);
  for(const [testKey,subject] of [[key,'owner-b'],[crypto.getRandomValues(new Uint8Array(32)),'owner-a']] as const){
    let rejected=false;try{await openRefresh(sealed,testKey,subject);}catch{rejected=true;}assert(rejected);
  }
});
