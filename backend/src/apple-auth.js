import {SignJWT,importPKCS8} from 'jose';
import {createCipheriv,createDecipheriv,randomBytes} from 'node:crypto';
import {readFileSync} from 'node:fs';

export function appleAuthFromEnv(env=process.env) {
  const required=['APPLE_CLIENT_ID','APPLE_TEAM_ID','APPLE_KEY_ID','APPLE_PRIVATE_KEY_PATH','TOKEN_ENCRYPTION_KEY'];
  if(required.some(key=>!env[key]))return null;
  const encryptionKey=Buffer.from(env.TOKEN_ENCRYPTION_KEY,'hex');
  if(encryptionKey.length!==32)throw new Error('TOKEN_ENCRYPTION_KEY must contain 32 bytes encoded as hex.');
  const pem=readFileSync(env.APPLE_PRIVATE_KEY_PATH,'utf8');
  const seal=token=>{const iv=randomBytes(12),cipher=createCipheriv('aes-256-gcm',encryptionKey,iv),encrypted=Buffer.concat([cipher.update(token,'utf8'),cipher.final()]);return Buffer.concat([iv,cipher.getAuthTag(),encrypted]).toString('base64');};
  const open=sealed=>{const data=Buffer.from(sealed,'base64'),decipher=createDecipheriv('aes-256-gcm',encryptionKey,data.subarray(0,12));decipher.setAuthTag(data.subarray(12,28));return Buffer.concat([decipher.update(data.subarray(28)),decipher.final()]).toString('utf8');};
  async function secret(){return new SignJWT({}).setProtectedHeader({alg:'ES256',kid:env.APPLE_KEY_ID}).setIssuer(env.APPLE_TEAM_ID).setIssuedAt().setExpirationTime('5m').setAudience('https://appleid.apple.com').setSubject(env.APPLE_CLIENT_ID).sign(await importPKCS8(pem,'ES256'));}
  return {
    async exchange(code){const response=await fetch('https://appleid.apple.com/auth/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:env.APPLE_CLIENT_ID,client_secret:await secret(),code,grant_type:'authorization_code'}),signal:AbortSignal.timeout(15000)});if(!response.ok)throw new Error('Apple authorization code exchange failed');const data=await response.json();if(!data.refresh_token||!data.id_token)throw new Error('Apple did not return refresh credentials');return {sealed:seal(data.refresh_token),identityToken:data.id_token};},
    async revoke(sealed){const response=await fetch('https://appleid.apple.com/auth/revoke',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:env.APPLE_CLIENT_ID,client_secret:await secret(),token:open(sealed),token_type_hint:'refresh_token'}),signal:AbortSignal.timeout(15000)});if(!response.ok)throw new Error('Apple token revocation failed');}
  };
}
