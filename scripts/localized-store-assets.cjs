// Exact localized captions around untouched XCTest captures from build 1015's source.
// Sharp/Pango shapes RTL and Indic text; no generated imitation interface or device claim.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const sharp=require(process.env.TAPLEAD_SHARP_PATH||'sharp');
const root=path.resolve(__dirname,'..');
const captureDir=path.join(root,'artifacts/nfc-removal-xcode-38035209175/screenshots');
const attachments=JSON.parse(fs.readFileSync(path.join(captureDir,'manifest.json'))).flatMap(x=>x.attachments);
const locales=JSON.parse(fs.readFileSync(path.join(root,'marketing/store-localizations.json')));
const out=path.join(root,'marketing/localized-assets');fs.mkdirSync(out,{recursive:true});
const subset=process.argv[2]?.split(',');
const fonts='C:/Windows/Fonts';
const native={'en-GB':'en','en-US':'en','en-AU':'en','en-CA':'en','es-ES':'es','es-MX':'es','fr-FR':'fr','fr-CA':'fr','de-DE':'de','it':'it','pt-BR':'pt','pt-PT':'pt','nl-NL':'nl','ja':'ja','ko':'ko','zh-Hans':'zh-Hans'};
const xml=x=>x.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
function source(prefix){const a=attachments.find(x=>x.suggestedHumanReadableName.startsWith(prefix));if(!a)throw Error('Missing actual capture '+prefix);return path.join(captureDir,a.exportedFileName)}
function font(locale){
 if(['bn','gu','hi','kn','ml','mr','or','pa','ta','te','th'].includes(locale))return ['Nirmala UI',path.join(fonts,'Nirmala.ttc')];
 if(locale.startsWith('zh'))return ['Microsoft YaHei',path.join(fonts,'msyh.ttc')];
 if(locale==='ja')return ['MS Gothic',path.join(fonts,'msgothic.ttc')];
 if(locale==='ko')return ['Malgun Gothic',path.join(fonts,'malgun.ttf')];
 if(['ar-SA','ur','he'].includes(locale))return ['Tahoma',path.join(fonts,'tahoma.ttf')];
 return ['Segoe UI',path.join(fonts,'segoeui.ttf')];
}
async function text(value,locale,width,maxHeight,size,color='#FFFFFF'){
 const [family,fontfile]=font(locale);
 for(let s=size;s>=28;s-=4){
  const {data,info}=await sharp({text:{text:`<span foreground="${color}" weight="bold">${xml(value)}</span>`,font:`${family} ${s}`,fontfile,width,align:['ar-SA','ur','he'].includes(locale)?'right':'left',rgba:true}}).png().toBuffer({resolveWithObject:true});
  if(info.height<=maxHeight)return {input:data,width:info.width,height:info.height};
 }
 throw Error('Caption cannot fit: '+locale+' '+value);
}
function background(W,H,light=false){return Buffer.from(`<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x2="1" y2="1"><stop stop-color="${light?'#F4F1FC':'#171225'}"/><stop offset="1" stop-color="${light?'#E4DAFC':'#36275A'}"/></linearGradient></defs><rect width="${W}" height="${H}" fill="url(#g)"/><circle cx="${W*.88}" cy="${H*.16}" r="${W*.6}" fill="#9F82FF" opacity=".07"/><path d="M0 ${H*.9} Q${W*.4} ${H*.73} ${W} ${H*.86}" fill="none" stroke="#AF93FF" stroke-width="2" opacity=".15"/></svg>`)}
const manifest=[];
async function save(buffer,file,record,png=false){
 const dest=path.join(out,file);fs.mkdirSync(path.dirname(dest),{recursive:true});
 const img=sharp(buffer).removeAlpha();if(png)await img.png({palette:true,colours:256,effort:6}).toFile(dest);else await img.jpeg({quality:93,chromaSubsampling:'4:4:4'}).toFile(dest);
 const md=await sharp(dest).metadata();if(md.hasAlpha)throw Error('Alpha channel');
 manifest.push({...record,file:file.replaceAll('\\','/'),width:md.width,height:md.height,sha256:crypto.createHash('sha256').update(fs.readFileSync(dest)).digest('hex')});
}
async function screen(locale,item,index,kind,W,H,fileSource){
 const light=index%2===1,fg=light?'#211A33':'#FFFFFF',accent=light?'#6550D5':'#C8B5FF';
 const margin=Math.round(W*.075),contentW=W-margin*2;
 const brand=await text('TapLead',locale,contentW,90,Math.round(W*.046),fg);
 const heading=await text(item.captions[index%4],locale,contentW,Math.round(H*.145),Math.round(W*.07),fg);
 const method=index===0?await text('QR',locale,150,80,Math.round(W*.034),accent):null;
 const top=Math.round(H*.255),bottom=Math.round(H*.965),availableH=bottom-top;
 const captured=await sharp(fileSource).resize({height:availableH,width:contentW,fit:'inside',withoutEnlargement:false}).png().toBuffer({resolveWithObject:true});
 const left=Math.round((W-captured.info.width)/2);
 const radius=50;
 const frame=Buffer.from(`<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg"><rect x="${left-10}" y="${top-10}" width="${captured.info.width+20}" height="${captured.info.height+20}" rx="${radius}" fill="${light?'#C1B5D9':'#65577D'}"/></svg>`);
 const layers=[{input:frame,left:0,top:0},{input:brand.input,left:margin,top:Math.round(H*.042)},{input:heading.input,left:margin,top:Math.round(H*.104)},{input:captured.data,left,top}];
 if(method)layers.push({input:method.input,left:margin,top:Math.round(H*.207)});
 const composed=await sharp(background(W,H,light)).composite(layers).png().toBuffer();
 await save(composed,path.join(locale,`${kind}-${String(index+1).padStart(2,'0')}.jpg`),{locale,placement:kind,index:index+1,caption:item.captions[index%4],capture:path.relative(root,fileSource).replaceAll('\\','/'),capture_ui_language:kind==='duo-outer'?'en':native[locale]||'en'});
}
async function hero(locale,item,cardSource){
 const W=5244,H=2950,margin=340;
 const brand=await text('TapLead',locale,2300,300,210);
 const heading=await text(item.captions[0],locale,2500,1100,260);
 const sub=await text(item.captions[2],locale,2450,350,110,'#C8B5FF');
 const capture=await sharp(cardSource).resize({height:2500}).png().toBuffer({resolveWithObject:true});
 const b=await sharp(background(W,H)).composite([{input:brand.input,left:margin,top:330},{input:heading.input,left:margin,top:850},{input:sub.input,left:margin,top:2110},{input:capture.data,left:Math.round(W-capture.info.width-360),top:225}]).png().toBuffer();
 await save(b,path.join(locale,'universal-header-search.png'),{locale,placement:'universal-header-search',caption:item.captions[0],capture:path.relative(root,cardSource).replaceAll('\\','/'),capture_ui_language:native[locale]||'en'},true);
}
(async()=>{
 for(const [locale,item] of Object.entries(locales)){
  if(subset&&!subset.includes(locale))continue;
  const language=native[locale]||'en';
  const core=['card','editor','contacts','today'].map(x=>source(`TapLead-locale-${language}-${x}_`));
  for(let i=0;i<4;i++){
   await screen(locale,item,i,'duo-inner',2007,2853,core[i]);
   await screen(locale,item,i,'iphone-medium',1206,2622,core[i]);
  }
  const styles=['minimal','creator','dark','consultant'].map(x=>source('TapLead-premium-'+x+'_'));
  for(let i=0;i<4;i++)await screen(locale,{...item,captions:item.captions.map(()=>item.captions[1])},i,'duo-outer',1398,2034,styles[i]);
  await hero(locale,item,core[0]);
  console.log('Exported:',locale);
 }
 fs.writeFileSync(path.join(out,subset?'preview-manifest.json':'manifest.json'),JSON.stringify({source_run:'https://github.com/lanray07/TapLead/actions/runs/38035209175',source_commit:'5b8fd1e',selected_build:1015,notes:'Real iPhone 17 Pro Max captures composed at accepted target dimensions without inventing a Duo-specific app layout. Localized captions; available native UI language, otherwise English. Outer-display design samples use actual English demo captures. Agent-authored translation; independent language review pending.',assets:manifest},null,2)+'\n');
})();

