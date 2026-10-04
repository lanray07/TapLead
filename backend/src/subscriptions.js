import {SignedDataVerifier,Environment} from '@apple/app-store-server-library';
import {readFileSync} from 'node:fs';

export const proProducts=['com.taplead.pro.monthly','com.taplead.pro.yearly'];
export function subscriptionVerifierFromEnv(env=process.env) {
  if(!env.APPLE_ROOT_CERT_PATHS||!env.APPLE_BUNDLE_ID)return null;
  const production=env.NODE_ENV==='production';
  if(production&&!env.APPLE_APP_ID)throw new Error('Set the numeric Apple App ID for production transaction verification.');
  const certs=env.APPLE_ROOT_CERT_PATHS.split(';').filter(Boolean).map(path=>readFileSync(path));
  return new SignedDataVerifier(certs,true,production?Environment.PRODUCTION:Environment.SANDBOX,env.APPLE_BUNDLE_ID,production?Number(env.APPLE_APP_ID):undefined);
}
export function planFor(db,owner){const pro=Boolean(db.prepare('SELECT owner FROM entitlements WHERE owner=? AND expires>? AND revoked=0').get(owner,Date.now()));return {pro,cardLimit:pro?20:1,leadLimit:pro?10000:50};}
export function storeTransaction(db,transaction,expectedOwner) {
  const owner=transaction.appAccountToken?.toLowerCase();
  if(!owner||owner!==expectedOwner||!proProducts.includes(transaction.productId)||!transaction.originalTransactionId||!Number.isFinite(transaction.expiresDate)||!Number.isFinite(transaction.signedDate))throw new Error('Subscription account or product mismatch');
  const user=db.prepare('SELECT id FROM users WHERE id=?').get(owner);if(!user)throw new Error('Subscription account no longer exists');
  const prior=db.prepare('SELECT * FROM entitlements WHERE original_id=?').get(transaction.originalTransactionId);
  if(prior&&prior.owner!==owner)throw new Error('Subscription already belongs to another account');
  // Prevent an old signed transaction replay from undoing a newer refund/revocation.
  if(prior&&prior.signed_date>=transaction.signedDate)return planFor(db,owner);
  db.prepare('INSERT INTO entitlements VALUES(?,?,?,?,?,?) ON CONFLICT(original_id) DO UPDATE SET product=excluded.product,expires=excluded.expires,revoked=excluded.revoked,signed_date=excluded.signed_date').run(transaction.originalTransactionId,owner,transaction.productId,transaction.expiresDate,transaction.revocationDate?1:0,transaction.signedDate);
  return planFor(db,owner);
}
