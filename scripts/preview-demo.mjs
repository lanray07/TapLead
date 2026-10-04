// Local recipient-profile preview only. Never run this seed against a deployed database.
import {openStore} from '../backend/src/store.js';
import {cardSchema} from '../backend/src/domain.js';
const db=openStore('backend/data/preview.sqlite');
const user='00000000-0000-4000-8000-000000000001',id='00000000-0000-4000-8000-000000000002';
db.prepare('INSERT OR IGNORE INTO users VALUES(?,?,?,?,?)').run(user,null,null,null,Date.now());
const card=cardSchema.parse({id,name:'Alex Morgan',preferredName:'Alex',title:'Brand strategist',company:'Morgan Studio',persona:'Demo · sample profile',headline:'Good conversations. Great possibilities.',bio:'I help ambitious businesses find their voice and build brands people remember.\n\nLet’s talk about what comes next.',email:'alex@example.com',website:'https://example.com',portfolio:'https://example.com/portfolio',location:'London, United Kingdom',publicFields:['email','website','portfolio','location'],published:true,analyticsEnabled:false});
db.prepare('INSERT INTO cards VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data').run(id,user,JSON.stringify(card));db.close();
console.log(`Demo profile: http://localhost:8787/p/${id}`);
