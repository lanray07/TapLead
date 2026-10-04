import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import sharp from 'sharp';
import {normaliseCardImage} from '../src/media.js';
import {openStore} from '../src/store.js';
import {createApp} from '../src/app.js';

test('media decoder rejects spoofed formats, oversized pixels and strips private metadata',async()=>{
  const source=await sharp({create:{width:800,height:600,channels:3,background:'#6654d9'}}).withExif({IFD0:{Artist:'Private test metadata'}}).jpeg().toBuffer();
  assert.ok((await sharp(source).metadata()).exif);
  const pixels=await normaliseCardImage(source,'image/jpeg');
  const metadata=await sharp(pixels).metadata();
  assert.equal(metadata.format,'png');assert.equal(metadata.width,512);assert.equal(metadata.height,384);assert.equal(metadata.exif,undefined);assert.equal(metadata.xmp,undefined);
  await assert.rejects(normaliseCardImage(Buffer.from('<svg><script>alert(1)</script></svg>'),'image/png'));
  await assert.rejects(normaliseCardImage(source,'image/png'));
  const bomb=await sharp({create:{width:3000,height:2000,channels:3,background:'#ffffff'}}).png().toBuffer();
  await assert.rejects(normaliseCardImage(bomb,'image/png'));
});
test('image ownership, publication visibility, export and cascade deletion hold',async()=>{
  const db=openStore(':memory:'),server=createApp(db).listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
  const base=`http://127.0.0.1:${server.address().port}`;
  const call=(path,method='GET',body,token)=>fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:body===undefined?undefined:JSON.stringify(body)});
  try {
    const owner=await (await call('/api/auth/register','POST',{email:'image@example.com',password:'very-safe-test-password'})).json();
    const other=await (await call('/api/auth/register','POST',{email:'other-image@example.com',password:'very-safe-test-password'})).json();
    const card={id:randomUUID(),name:'Alex',published:true,cornerImageKind:'Logo',cornerImagePosition:'Bottom right'};
    assert.equal((await call(`/api/cards/${card.id}`,'PUT',card,owner.token)).status,200);
    const image=await sharp({create:{width:32,height:32,channels:4,background:'#6654d9'}}).png().toBuffer();
    const upload=token=>fetch(base+`/api/cards/${card.id}/image?kind=Logo`,{method:'PUT',headers:{'Content-Type':'image/png',Authorization:`Bearer ${token}`},body:image});
    assert.equal((await upload(other.token)).status,404);assert.equal((await upload(owner.token)).status,204);
    assert.equal((await fetch(base+`/p/${card.id}/image`)).status,200);
    assert.ok((await (await fetch(base+`/p/${card.id}`)).text()).includes('corner-image bottom-right logo'));
    const exported=await (await call('/api/export','GET',undefined,owner.token)).json();assert.ok(exported.cards[0].logoData);
    assert.deepEqual((await (await call('/api/cards','GET',undefined,other.token)).json()),[]);
    card.published=false;await call(`/api/cards/${card.id}`,'PUT',card,owner.token);assert.equal((await fetch(base+`/p/${card.id}/image`)).status,404);
    card.published=true;card.cornerImageKind='None';await call(`/api/cards/${card.id}`,'PUT',card,owner.token);assert.equal((await fetch(base+`/p/${card.id}/image`)).status,404);
    assert.equal((await call(`/api/cards/${card.id}/image`,'DELETE',undefined,other.token)).status,404);
    assert.equal((await call('/api/account','DELETE',undefined,owner.token)).status,204);
    assert.equal(db.prepare('SELECT count(*) n FROM card_media').get().n,0);
  } finally {await new Promise(resolve=>server.close(resolve));db.close();}
});
