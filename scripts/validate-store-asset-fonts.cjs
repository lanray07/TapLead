// Read installed font cmap tables to detect missing caption glyphs before export.
const fs=require('fs');
const copy=JSON.parse(fs.readFileSync('marketing/store-localizations.json'));
const fontFile=locale=>['bn','gu','hi','kn','ml','mr','or','pa','ta','te'].includes(locale)?'Nirmala.ttc':locale.startsWith('zh')?'msyh.ttc':locale==='ja'?'msgothic.ttc':locale==='ko'?'malgun.ttf':['ar-SA','ur','he','th'].includes(locale)?'tahoma.ttf':'segoeui.ttf';
const cache=new Map();
function glyphs(file){
 if(cache.has(file))return cache.get(file);
 const b=fs.readFileSync('C:/Windows/Fonts/'+file), starts=b.toString('ascii',0,4)==='ttcf'?Array.from({length:b.readUInt32BE(8)},(_,i)=>b.readUInt32BE(12+i*4)):[0];
 const subtables=[];
 for(const start of starts){
  const n=b.readUInt16BE(start+4);
  for(let i=0;i<n;i++){
   const entry=start+12+i*16;if(b.toString('ascii',entry,entry+4)!=='cmap')continue;
   const cmap=b.readUInt32BE(entry+8), records=b.readUInt16BE(cmap+2);
   for(let j=0;j<records;j++){const offset=cmap+b.readUInt32BE(cmap+4+j*8+4);if([4,12].includes(b.readUInt16BE(offset)))subtables.push(offset);}
  }
 }
 const contains=cp=>subtables.some(o=>{
  const format=b.readUInt16BE(o);
  if(format===12){const n=b.readUInt32BE(o+12);for(let i=0;i<n;i++){const g=o+16+i*12,a=b.readUInt32BE(g),z=b.readUInt32BE(g+4);if(cp>=a&&cp<=z)return b.readUInt32BE(g+8)+cp-a!==0;}return false;}
  if(cp>65535)return false;
  const n=b.readUInt16BE(o+6)/2;
  for(let i=0;i<n;i++){
   const a=b.readUInt16BE(o+16+n*2+i*2),z=b.readUInt16BE(o+14+i*2);if(cp<a||cp>z)continue;
   const delta=b.readInt16BE(o+16+n*4+i*2),pos=o+16+n*6+i*2,range=b.readUInt16BE(pos);
   if(!range)return ((cp+delta)&65535)!==0;
   const glyph=b.readUInt16BE(pos+range+(cp-a)*2);return glyph!==0&&((glyph+delta)&65535)!==0;
  }
  return false;
 });
 cache.set(file,contains);return contains;
}
const report=Object.entries(copy).map(([locale,item])=>({locale,font:fontFile(locale),missing:[...new Set([...item.captions.join('')].filter(c=>!/[\s\p{Cf}]/u.test(c)&&!glyphs(fontFile(locale))(c.codePointAt(0))))]}));
fs.mkdirSync('artifacts/storefront',{recursive:true});fs.writeFileSync('artifacts/storefront/font-coverage.json',JSON.stringify(report,null,2)+'\n');
const failed=report.filter(r=>r.missing.length);console.log(JSON.stringify({locales:report.length,missing:failed}));if(failed.length)process.exitCode=1;
