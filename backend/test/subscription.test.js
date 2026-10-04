import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {openStore} from '../src/store.js';
import {storeTransaction,planFor} from '../src/subscriptions.js';

test('verified entitlement logic binds accounts, respects expiration and prevents revocation replay',()=>{
  const db=openStore(':memory:'),owner=randomUUID(),other=randomUUID();
  db.prepare('INSERT INTO users VALUES(?,?,?,?,?)').run(owner,null,null,null,Date.now());
  db.prepare('INSERT INTO users VALUES(?,?,?,?,?)').run(other,null,null,null,Date.now());
  const tx={appAccountToken:owner.toUpperCase(),productId:'com.taplead.pro.monthly',originalTransactionId:'original-1',expiresDate:Date.now()+86400000,signedDate:Date.now()};
  assert.equal(storeTransaction(db,tx,owner).pro,true);
  assert.equal(planFor(db,other).pro,false);
  assert.throws(()=>storeTransaction(db,tx,other));
  assert.equal(storeTransaction(db,{...tx,revocationDate:Date.now(),signedDate:tx.signedDate+1000},owner).pro,false);
  assert.equal(storeTransaction(db,tx,owner).pro,false);
  assert.throws(()=>storeTransaction(db,{...tx,productId:'unrecognised.product'},owner));
  assert.equal(storeTransaction(db,{...tx,originalTransactionId:'expired',expiresDate:Date.now()-1},owner).pro,false);
  db.close();
});
