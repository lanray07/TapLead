import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
export function openStore(path) {
  if(path !== ':memory:') mkdirSync(dirname(path), {recursive:true});
  const db = new DatabaseSync(path);
  db.exec(`PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL;
    CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY,email TEXT UNIQUE,password TEXT,apple_sub TEXT UNIQUE,created INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS sessions(hash TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,expires INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS cards(id TEXT PRIMARY KEY,owner TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,data TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS leads(id TEXT PRIMARY KEY,owner TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,data TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS events(id INTEGER PRIMARY KEY,card_id TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,kind TEXT NOT NULL,source TEXT NOT NULL,created INTEGER NOT NULL);
    CREATE INDEX IF NOT EXISTS event_card_date ON events(card_id,created);
    CREATE TABLE IF NOT EXISTS challenges(nonce TEXT PRIMARY KEY,expires INTEGER NOT NULL);`);
  db.exec('CREATE TABLE IF NOT EXISTS apple_credentials(user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,sealed_refresh TEXT NOT NULL);');
  db.exec('CREATE TABLE IF NOT EXISTS entitlements(original_id TEXT PRIMARY KEY,owner TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,product TEXT NOT NULL,expires INTEGER NOT NULL,revoked INTEGER NOT NULL,signed_date INTEGER NOT NULL);');
  db.exec('CREATE TABLE IF NOT EXISTS card_media(card_id TEXT PRIMARY KEY REFERENCES cards(id) ON DELETE CASCADE,kind TEXT NOT NULL CHECK(kind IN (\'Photo\',\'Logo\')),pixels BLOB NOT NULL);');
  return db;
}
