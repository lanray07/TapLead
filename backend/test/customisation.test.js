import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {cardSchema,publicCard,cardCSS} from '../src/domain.js';
import {profileHTML} from '../src/public.js';
import {openStore} from '../src/store.js';
import {createApp} from '../src/app.js';

test('public custom actions do not expose private targets and labels are escaped',()=>{
  const card=cardSchema.parse({id:randomUUID(),name:'Alex',customBackground:'FFFFFF',typography:'Serif',primaryAction:'Book a meeting',primaryActionLabel:'<script>unsafe</script>',booking:'https://example.com/private'});
  assert.equal(publicCard(card).booking,undefined);
  assert.ok(!profileHTML(card,'qr','').includes('example.com/private'));
  card.publicFields=['booking'];
  const page=profileHTML(card,'qr','');
  assert.ok(page.includes('&lt;script&gt;unsafe&lt;/script&gt;'));
  assert.ok(page.includes(`/go/booking?source=qr`));
  assert.ok(cardCSS(card).includes('color:#000'));
  assert.ok(cardCSS(card).includes('ui-serif'));
  assert.equal(cardSchema.safeParse({...card,customBackground:'red;display:none'}).success,false);
  assert.equal(cardSchema.safeParse({...card,typography:'url(https://evil.example)'}).success,false);
});
test('server rejects forged Pro styling and accepts styling only for verified entitlement',async()=>{
  const db=openStore(':memory:');const server=createApp(db).listen(0,'127.0.0.1');
  await new Promise(resolve=>server.once('listening',resolve));
  try {
    const base=`http://127.0.0.1:${server.address().port}`;
    const auth=await (await fetch(base+'/api/auth/register',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:'style@example.com',password:'very-safe-test-password'})})).json();
    const card={id:randomUUID(),name:'Alex',customBackground:'FFFFFF',typography:'Serif',published:true,cv:'https://example.com/cv',publicFields:['cv'],primaryAction:'View CV'};
    const put=()=>fetch(base+`/api/cards/${card.id}`,{method:'PUT',headers:{'Content-Type':'application/json',Authorization:`Bearer ${auth.token}`},body:JSON.stringify(card)});
    assert.equal((await put()).status,403);
    db.prepare('INSERT INTO entitlements VALUES(?,?,?,?,?,?)').run('verified-test-transaction',auth.userID,'com.taplead.pro.monthly',Date.now()+86400000,0,Date.now());
    assert.equal((await put()).status,200);
    const css=await fetch(base+`/p/${card.id}/theme.css`);assert.equal(css.status,200);assert.ok((await css.text()).includes('ui-serif'));
    const link=await fetch(base+`/p/${card.id}/go/cv`,{redirect:'manual'});assert.equal(link.status,303);assert.equal(link.headers.get('location'),card.cv);
  } finally {await new Promise(resolve=>server.close(resolve));db.close();}
});
