// Editable SVG marketing layouts embed the genuine simulator captures unchanged.
// Rasterize the layout, rather than generating an imitation app interface.
const fs=require('fs'),path=require('path');
const sharp=require(process.env.TAPLEAD_SHARP_PATH || 'sharp');
const root=path.resolve(__dirname,'..');
const captures=path.join(root,'artifacts/github/37195819458/screenshots');
const out=path.join(root,'marketing/assets');fs.mkdirSync(out,{recursive:true});
const shots=[
 ['01-card','E813B3D1-196D-4EB8-85E6-0C9FD1F5B8BA.png',['Make your','first impression.'],'A business card that feels like you.'],
 ['02-connections','38994EE8-C0A7-4509-8475-59603264E416.png',['New connection.','Lasting context.'],'Keep your contacts, tags and notes together.'],
 ['03-today','2932653E-52C7-4654-AF89-DB5C6ACDE6B8.png',['Give every meeting','a next step.'],'Keep your upcoming follow-ups in view.'],
 ['04-insights','5F33B535-DEBD-48FE-BE71-A3F7B1850A06.png',['Your networking,','at a glance.'],'Explore your activity in one calm space.']
];
const escape=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;');
(async()=>{
 for(const [size,W,H] of [['6.5',1242,2688],['6.9',1320,2868]]){
  const scale=W/1242;
  for(let i=0;i<shots.length;i++){
   const [name,file,headline,sub]=shots[i];
   const data=fs.readFileSync(path.join(captures,file)).toString('base64');
   const light=i%2===1,bg=light?'#F4F1FC':'#181322',fg=light?'#211A33':'#FFFFFF';
   const svg=`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${W}" height="${H}" viewBox="0 0 1242 ${H/scale}">
   <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="${bg}"/><stop offset="1" stop-color="${light?'#E6DCFF':'#302248'}"/></linearGradient><clipPath id="screen"><rect x="171" y="645" width="900" height="1955.45" rx="66"/></clipPath></defs>
   <rect width="1242" height="${H/scale}" fill="url(#g)"/>
   <circle cx="1110" cy="570" r="430" fill="#7760E4" opacity=".08"/>
   <g font-family="Arial, sans-serif"><text x="92" y="120" font-size="42" font-weight="700" fill="${fg}">TapLead<tspan fill="${light?'#6654D9':'#BFAAFF'}"> / </tspan><tspan font-weight="400" font-size="32">Connect with purpose</tspan></text>
   <text x="92" y="278" font-size="91" font-weight="700" letter-spacing="-3" fill="${fg}">${escape(headline[0])}</text>
   <text x="92" y="382" font-size="91" font-weight="700" letter-spacing="-3" fill="${light?'#6654D9':'#C2ACFF'}">${escape(headline[1])}</text>
   <text x="92" y="477" font-size="36" fill="${light?'#655E76':'#C3BBCE'}">${escape(sub)}</text>
   <text x="92" y="553" font-size="25" letter-spacing="3" fill="${light?'#817895':'#9D91B3'}">ACTUAL APP · DEMO DATA</text></g>
   <rect x="150" y="623" width="942" height="1998" rx="88" fill="#09070D"/><rect x="159" y="632" width="924" height="1980" rx="78" fill="#37303F"/>
   <image x="171" y="645" width="900" height="1955.45" clip-path="url(#screen)" xlink:href="data:image/png;base64,${data}"/>
   </svg>`;
   const base=path.join(out,`${name}-${size}`);fs.writeFileSync(base+'.svg',svg);
   await sharp(Buffer.from(svg)).png().toFile(base+'.png');
  }
 }
 if(process.argv[2]) await sharp(process.argv[2]).resize(1024,1024,{fit:'contain'}).removeAlpha().png().toFile(path.join(out,'pro-monthly-promotion.png'));
 console.log('Saved 8 screenshot compositions and monthly promotion in marketing/assets');
})();
