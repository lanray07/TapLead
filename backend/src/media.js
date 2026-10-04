import sharp from 'sharp';

export async function normaliseCardImage(input,contentType) {
  if(!Buffer.isBuffer(input)||!input.length||input.length>2*1024*1024)throw new Error('Invalid image size');
  const png=input.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
  const jpeg=input[0]===255&&input[1]===216&&input[2]===255;
  if(!(png&&contentType==='image/png')&&!(jpeg&&contentType==='image/jpeg'))throw new Error('Invalid image type');
  const image=sharp(input,{limitInputPixels:4*1024*1024,limitInputChannels:4,failOn:'warning'});
  const metadata=await image.metadata();
  if(!['jpeg','png'].includes(metadata.format)||(metadata.pages||1)!==1)throw new Error('Invalid image format');
  // Re-encode decoded pixels, apply orientation and drop EXIF/GPS/text/ICC metadata.
  const output=await image.rotate().resize(512,512,{fit:'inside',withoutEnlargement:true}).png().toBuffer();
  if(output.length>2*1024*1024)throw new Error('Invalid image size');
  return output;
}
