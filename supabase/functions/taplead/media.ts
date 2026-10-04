// @deno-types="npm:@types/pngjs@6.0.5"
import { PNG } from 'pngjs';
import jpeg from 'jpeg-js';
import { Buffer } from 'node:buffer';

const maxBytes=2*1024*1024, maxPixels=4*1024*1024;
const signature=[137,80,78,71,13,10,26,10];
const text=new TextDecoder();
// Inspect allocation size and reject animation before invoking a decoder.
export function imageDimensions(bytes:Uint8Array,mime:string):[number,number] {
  if(!bytes.length || bytes.length>maxBytes)throw new Error('Invalid image size');
  const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
  let width=0,height=0;
  if(mime==='image/png' && signature.every((v,i)=>bytes[i]===v)) {
    let offset=8,header=false,end=false;
    while(offset+12<=bytes.length) {
      const size=view.getUint32(offset),kind=text.decode(bytes.subarray(offset+4,offset+8));
      if(size>bytes.length-offset-12)throw new Error('Invalid PNG chunk');
      if(!header) {
        if(kind!=='IHDR'||size!==13)throw new Error('Invalid PNG header');
        width=view.getUint32(offset+8);height=view.getUint32(offset+12);header=true;
      } else if(kind==='IHDR')throw new Error('Duplicate PNG header');
      if(['acTL','fcTL','fdAT'].includes(kind))throw new Error('Animated images are not supported');
      offset+=size+12;
      if(kind==='IEND'){end=true;break;}
    }
    if(!end || offset!==bytes.length)throw new Error('Invalid PNG ending');
  } else if(mime==='image/jpeg' && bytes[0]===255 && bytes[1]===216) {
    let offset=2;
    while(offset+4<=bytes.length) {
      if(bytes[offset++]!==255)throw new Error('Invalid JPEG marker');
      while(bytes[offset]===255)offset++;
      const marker=bytes[offset++];
      if(marker===217||marker===218)break;
      if(marker===216||marker===1||(marker>=208&&marker<=215))continue;
      const size=view.getUint16(offset);
      if(size<2 || offset+size>bytes.length)throw new Error('Invalid JPEG segment');
      // Reject MPO multi-picture files; only a single still image is accepted.
      if(marker===226 && text.decode(bytes.subarray(offset+2,offset+6))==='MPF\0')throw new Error('Multiple images are not supported');
      if([192,193,194].includes(marker)) {
        if(size<8||bytes[offset+7]>4)throw new Error('Invalid JPEG channels');
        height=view.getUint16(offset+3);width=view.getUint16(offset+5);
      }
      offset+=size;
    }
  } else throw new Error('Invalid image type');
  if(!width||!height||width*height>maxPixels)throw new Error('Invalid image dimensions');
  return [width,height];
}
function orientation(bytes:Uint8Array):number {
  const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);let offset=2;
  while(offset+4<=bytes.length) {
    if(bytes[offset++]!==255)break;while(bytes[offset]===255)offset++;
    const marker=bytes[offset++];if(marker===218||marker===217)break;
    const length=view.getUint16(offset);
    if(length<2||offset+length>bytes.length)throw new Error('Invalid JPEG segment');
    if(marker===225&&text.decode(bytes.subarray(offset+2,offset+8))==='Exif\0\0') {
      const start=offset+8,end=offset+length;
      if(start+8>end)throw new Error('Invalid EXIF');
      const endian=text.decode(bytes.subarray(start,start+2)),little=endian==='II';
      if(!['II','MM'].includes(endian)||view.getUint16(start+2,little)!==42)throw new Error('Invalid EXIF');
      const ifd=start+view.getUint32(start+4,little);if(ifd+2>end)throw new Error('Invalid EXIF');
      const count=view.getUint16(ifd,little);if(count>256||ifd+2+count*12>end)throw new Error('Invalid EXIF');
      for(let i=0;i<count;i++){const entry=ifd+2+i*12;if(view.getUint16(entry,little)===274){if(view.getUint16(entry+2,little)!==3||view.getUint32(entry+4,little)!==1)throw new Error('Invalid EXIF orientation');const value=view.getUint16(entry+8,little);if(value<1||value>8)throw new Error('Invalid EXIF orientation');return value;}}
    }
    offset+=length;
  }
  return 1;
}
export async function normaliseImage(bytes:Uint8Array,mime:string):Promise<Uint8Array> {
  const [width,height]=imageDimensions(bytes,mime);
  const decoded=mime==='image/png'?PNG.sync.read(Buffer.from(bytes),{checkCRC:true}):jpeg.decode(bytes,{useTArray:true,tolerantDecoding:false,maxResolutionInMP:4.2,maxMemoryUsageInMB:64});
  if(decoded.width!==width||decoded.height!==height||decoded.data.length!==width*height*4)throw new Error('Image decode mismatch');
  const orient=mime==='image/jpeg'?orientation(bytes):1;
  const ow=orient>=5?height:width,oh=orient>=5?width:height,scale=Math.min(1,512/Math.max(ow,oh));
  const w=Math.max(1,Math.round(ow*scale)),h=Math.max(1,Math.round(oh*scale));
  const pixels=Buffer.alloc(w*h*4);
  const index=(x:number,y:number)=>{
    let sx=x,sy=y;
    switch(orient){case 2:sx=width-1-x;break;case 3:sx=width-1-x;sy=height-1-y;break;case 4:sy=height-1-y;break;case 5:sx=y;sy=x;break;case 6:sx=y;sy=height-1-x;break;case 7:sx=width-1-y;sy=height-1-x;break;case 8:sx=width-1-y;sy=x;break;}
    return (sy*width+sx)*4;
  };
  // Bilinear resampling in premultiplied alpha keeps transparent logos free of halos.
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    const fx=Math.max(0,Math.min(ow-1,(x+.5)*ow/w-.5)),fy=Math.max(0,Math.min(oh-1,(y+.5)*oh/h-.5));
    const x0=Math.floor(fx),y0=Math.floor(fy),dx=fx-x0,dy=fy-y0;
    const positions=[index(x0,y0),index(Math.min(ow-1,x0+1),y0),index(x0,Math.min(oh-1,y0+1)),index(Math.min(ow-1,x0+1),Math.min(oh-1,y0+1))];
    const weights=[(1-dx)*(1-dy),dx*(1-dy),(1-dx)*dy,dx*dy],out=(y*w+x)*4;
    let alpha=0;for(let i=0;i<4;i++)alpha+=decoded.data[positions[i]+3]*weights[i];pixels[out+3]=Math.round(alpha);
    for(let channel=0;channel<3;channel++){let value=0;for(let i=0;i<4;i++)value+=decoded.data[positions[i]+channel]*decoded.data[positions[i]+3]*weights[i];pixels[out+channel]=alpha?Math.round(value/alpha):0;}
  }
  // Encode only fresh RGBA pixels. EXIF/GPS/text/ICC never enter the stored PNG.
  const canonical=new PNG({width:w,height:h});canonical.data=pixels;canonical.gamma=0;
  const output=PNG.sync.write(canonical,{colorType:6,inputColorType:6});
  if(output.length>maxBytes)throw new Error('Image output too large');return output;
}
