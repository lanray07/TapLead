import {SignedDataVerifier,Environment,type JWSTransactionDecodedPayload} from '@apple/app-store-server-library';
import {Buffer} from 'node:buffer';
import roots from './apple-roots.json' with {type:'json'};

export const productionVerifier=new SignedDataVerifier(roots.map(root=>Buffer.from(root,'base64')),true,Environment.PRODUCTION,'com.TapLead.app',6818982306);
export const sandboxVerifier=new SignedDataVerifier(roots.map(root=>Buffer.from(root,'base64')),true,Environment.SANDBOX,'com.TapLead.app');
const products=['com.taplead.pro.monthly','com.taplead.pro.yearly'];
// Call only on a payload returned by Apple's cryptographic verifier.
export function transactionRecord(t:JWSTransactionDecodedPayload,expectedOwner?:string) {
  const owner=t.appAccountToken?.toLowerCase();
  if(!owner||!/^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$/.test(owner)||expectedOwner&&owner!==expectedOwner.toLowerCase())throw new Error('Subscription account mismatch');
  if(t.bundleId!=='com.TapLead.app'||!products.includes(t.productId||'')||!t.originalTransactionId||!/^\d{1,64}$/.test(t.originalTransactionId)||!Number.isSafeInteger(t.expiresDate)||!Number.isSafeInteger(t.signedDate)||t.type!=='Auto-Renewable Subscription')throw new Error('Subscription payload mismatch');
  if(t.environment!==Environment.PRODUCTION&&t.environment!==Environment.SANDBOX)throw new Error('Unsupported subscription environment');
  return {owner,original_id:t.originalTransactionId,product:t.productId!,expires:t.expiresDate!,revoked:Boolean(t.revocationDate),signed_date:t.signedDate!,environment:t.environment};
}
export async function verifyTransaction(signed:string,owner:string) {
  // Sandbox validation is separate and never yields a Production entitlement.
  try{return transactionRecord(await productionVerifier.verifyAndDecodeTransaction(signed),owner);}
  catch(productionError){try{return transactionRecord(await sandboxVerifier.verifyAndDecodeTransaction(signed),owner);}catch{throw productionError;}}
}
export async function verifyNotification(signed:string) {
  let verifier=productionVerifier;
  let notification;
  try{notification=await verifier.verifyAndDecodeNotification(signed);}
  catch{verifier=sandboxVerifier;notification=await verifier.verifyAndDecodeNotification(signed);}
  if(notification.notificationType==='TEST')return null;
  const data=notification.data;
  if(!data?.signedTransactionInfo)throw new Error('Missing subscription transaction');
  const record=transactionRecord(await verifier.verifyAndDecodeTransaction(data.signedTransactionInfo));
  if(!Number.isSafeInteger(notification.signedDate))throw new Error('Missing notification date');
  record.signed_date=Math.max(record.signed_date,notification.signedDate!);
  if(notification.notificationType==='DID_FAIL_TO_RENEW'&&notification.subtype==='GRACE_PERIOD'&&!record.revoked) {
    if(!data.signedRenewalInfo)throw new Error('Missing signed grace information');
    const renewal=await verifier.verifyAndDecodeRenewalInfo(data.signedRenewalInfo);
    if(renewal.originalTransactionId!==record.original_id||renewal.environment!==record.environment||!Number.isSafeInteger(renewal.gracePeriodExpiresDate))throw new Error('Grace subscription mismatch');
    record.expires=Math.max(record.expires,renewal.gracePeriodExpiresDate!);
  }
  return record;
}
