import {SignJWT,importPKCS8,createRemoteJWKSet,jwtVerify} from 'jose';
import {Buffer} from 'node:buffer';

const clientID='com.TapLead.app';
const keys=createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));
const encoder=new TextEncoder();
export async function nonceHash(nonce:string){return Buffer.from(await crypto.subtle.digest('SHA-256',encoder.encode(nonce))).toString('hex');}
export async function sealRefresh(token:string,key:Uint8Array,subject:string) {
  const iv=crypto.getRandomValues(new Uint8Array(12));
  const imported=await crypto.subtle.importKey('raw',key as BufferSource,'AES-GCM',false,['encrypt']);
  const encrypted=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:encoder.encode(subject)},imported,encoder.encode(token));
  return Buffer.concat([Buffer.from(iv),Buffer.from(encrypted)]).toString('base64');
}
export async function openRefresh(sealed:string,key:Uint8Array,subject:string) {
  const bytes=Buffer.from(sealed,'base64');if(bytes.length<29)throw new Error('Invalid protected credential');
  const imported=await crypto.subtle.importKey('raw',key as BufferSource,'AES-GCM',false,['decrypt']);
  const decoded=await crypto.subtle.decrypt({name:'AES-GCM',iv:bytes.subarray(0,12),additionalData:encoder.encode(subject)},imported,bytes.subarray(12));
  return new TextDecoder().decode(decoded);
}
export function appleAuth(config:{team:string;keyID:string;pem:string;encryptionKey:string}) {
  if(!config.team||!config.keyID||!config.pem||!config.encryptionKey)return null;
  if(!/^[a-fA-F0-9]{64}$/.test(config.encryptionKey))throw new Error('Invalid Apple credential encryption configuration');
  const key=Buffer.from(config.encryptionKey,'hex');
  async function secret(){return new SignJWT({}).setProtectedHeader({alg:'ES256',kid:config.keyID}).setIssuer(config.team).setIssuedAt().setExpirationTime('5m').setAudience('https://appleid.apple.com').setSubject(clientID).sign(await importPKCS8(config.pem,'ES256'));}
  async function verify(token:string){return (await jwtVerify(token,keys,{issuer:'https://appleid.apple.com',audience:clientID,algorithms:['RS256']})).payload;}
  return {
    async exchange(identityToken:string,nonce:string,code:string) {
      const identity=await verify(identityToken);
      if(!identity.sub||identity.nonce!==await nonceHash(nonce))throw new Error('Apple challenge mismatch');
      const response=await fetch('https://appleid.apple.com/auth/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:clientID,client_secret:await secret(),code,grant_type:'authorization_code'}),signal:AbortSignal.timeout(15000)});
      if(!response.ok)throw new Error('Apple code exchange failed');
      const data=await response.json();if(typeof data.refresh_token!=='string'||typeof data.id_token!=='string')throw new Error('Missing Apple refresh credential');
      const exchanged=await verify(data.id_token);
      if(exchanged.sub!==identity.sub||exchanged.nonce!==identity.nonce)throw new Error('Apple exchange identity mismatch');
      return {subject:identity.sub,sealed:await sealRefresh(data.refresh_token,key,identity.sub)};
    },
    async revoke(subject:string,sealed:string) {
      const response=await fetch('https://appleid.apple.com/auth/revoke',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:clientID,client_secret:await secret(),token:await openRefresh(sealed,key,subject),token_type_hint:'refresh_token'}),signal:AbortSignal.timeout(15000)});
      if(!response.ok)throw new Error('Apple grant revocation failed');
    }
  };
}
