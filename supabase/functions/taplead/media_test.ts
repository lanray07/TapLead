// @deno-types="npm:@types/pngjs@6.0.5"
import { PNG } from 'pngjs';
import jpeg from 'jpeg-js';
import { Buffer } from 'node:buffer';
import { imageDimensions,normaliseImage } from './media.ts';

function assert(value:unknown,message='Assertion failed'):asserts value {if(!value)throw new Error(message);}
function rejects(action:()=>unknown){try{action();}catch{return;}throw new Error('Expected rejection');}
function fixture(width:number,height:number){const png=new PNG({width,height});for(let i=0;i<png.data.length;i+=4)png.data.set([0x23,0x45,0x67,255],i);return png;}
Deno.test('only valid, bounded still images pass the allocation guard',async()=>{
  const png=PNG.sync.write(fixture(6,4));
  assert(imageDimensions(png,'image/png').join(',')==='6,4');
  rejects(()=>imageDimensions(png,'image/jpeg'));
  rejects(()=>imageDimensions(png.subarray(0,20),'image/png'));
  const huge=png.slice();new DataView(huge.buffer,huge.byteOffset,huge.byteLength).setUint32(16,2000000);
  rejects(()=>imageDimensions(huge,'image/png'));
  const trailing=new Uint8Array(png.length+1);trailing.set(png);rejects(()=>imageDimensions(trailing,'image/png'));
  rejects(()=>imageDimensions(new Uint8Array(2*1024*1024+1),'image/png'));
});
Deno.test('decoded pixels are bounded and re-encoded without user metadata',async()=>{
  const png=PNG.sync.write(fixture(1000,600));const output=await normaliseImage(png,'image/png');
  const result=PNG.sync.read(Buffer.from(output));assert(result.width===512&&result.height===307);
  assert(result.data[(20*512+20)*4]===0x23);
  assert(!new TextDecoder().decode(output).includes('Exif'));
});
Deno.test('JPEG is decoded into a canonical PNG',async()=>{
  const encoded=jpeg.encode(fixture(12,8),90).data;const output=await normaliseImage(encoded,'image/jpeg');
  assert(output[0]===137&&output[1]===80);const decoded=PNG.sync.read(Buffer.from(output));
  assert(decoded.width===12&&decoded.height===8);
});
Deno.test('APNG animation is rejected before decode',async()=>{
  const png=PNG.sync.write(fixture(2,2));
  // Insert an animation-control chunk directly after IHDR. The header guard must
  // reject it even before any CRC/decompression is attempted.
  const animated=new Uint8Array(png.length+20);animated.set(png.subarray(0,33));
  const chunk=new Uint8Array(20);new DataView(chunk.buffer).setUint32(0,8);chunk.set(new TextEncoder().encode('acTL'),4);
  animated.set(chunk,33);animated.set(png.subarray(33),53);
  rejects(()=>imageDimensions(animated,'image/png'));
});

Deno.test('EXIF orientation is applied while metadata is discarded',async()=>{
  const encoded=jpeg.encode(fixture(12,8),90).data;
  const exif=Buffer.from([255,225,0,34,69,120,105,102,0,0,73,73,42,0,8,0,0,0,1,0,18,1,3,0,1,0,0,0,6,0,0,0,0,0,0,0]);
  const rotated=Buffer.concat([encoded.subarray(0,2),exif,encoded.subarray(2)]);
  const output=await normaliseImage(rotated,'image/jpeg'),decoded=PNG.sync.read(Buffer.from(output));
  assert(decoded.width===8&&decoded.height===12);
  assert(!new TextDecoder().decode(output).includes('Exif'));
});
