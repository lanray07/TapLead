// Compose App Store layouts around untouched native XCTest screenshots.
// Usage: node scripts/premium-store-assets.cjs artifacts/github/<run>/screenshots
const fs=require('fs'),path=require('path');
const sharp=require(process.env.TAPLEAD_SHARP_PATH || 'sharp');
const captures=path.resolve(process.argv[2]);
const manifest=JSON.parse(fs.readFileSync(path.join(captures,'manifest.json'),'utf8'));
const attachments=manifest.flatMap(test=>test.attachments);
const out=path.resolve(__dirname,'../marketing/assets');
const samples=[
 ['04-minimal','minimal',['Less clutter.','More presence.']],
 ['05-creator','creator',['Make it','uniquely yours.']],
 ['06-bold','bold',['Make a bold','introduction.']],
 ['07-dark','dark',['A sharper','first impression.']],
 ['08-elegant','elegant',['Quiet detail.','Lasting presence.']],
 ['09-sales','sales',['Ready for your','next conversation.']],
 ['10-consultant','consultant',['Clarity, from','the first hello.']]
];
const escape=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;');
(async()=>{
 for(const [size,W,H] of [['6.5',1242,2688],['6.9',1320,2868]]) {
  for(let i=0;i<samples.length;i++) {
   const [name,theme,headline]=samples[i];
   const capture=attachments.find(a=>a.suggestedHumanReadableName.startsWith(`TapLead-premium-${theme}_`));
   if(!capture) throw new Error(`Missing native capture: ${theme}`);
   const data=fs.readFileSync(path.join(captures,capture.exportedFileName)).toString('base64');
   const light=i%2===0,fg=light?'#211A33':'#FFFFFF',accent=light?'#6654D9':'#C2ACFF';
   const svg=`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${W}" height="${H}" viewBox="0 0 1242 ${H/(W/1242)}">
    <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="${light?'#F4F1FC':'#181322'}"/><stop offset="1" stop-color="${light?'#E6DCFF':'#302248'}"/></linearGradient><clipPath id="screen"><rect x="171" y="645" width="900" height="1955.45" rx="66"/></clipPath></defs>
    <rect width="1242" height="${H/(W/1242)}" fill="url(#g)"/>
    <circle cx="1110" cy="570" r="430" fill="#7760E4" opacity=".08"/>
    <g font-family="Arial, sans-serif"><text x="92" y="120" font-size="42" font-weight="700" fill="${fg}">TapLead<tspan fill="${accent}"> / </tspan><tspan font-weight="400" font-size="32">Connect with purpose</tspan></text>
    <text x="92" y="278" font-size="86" font-weight="700" letter-spacing="-3" fill="${fg}">${escape(headline[0])}</text>
    <text x="92" y="382" font-size="86" font-weight="700" letter-spacing="-3" fill="${accent}">${escape(headline[1])}</text>
    <text x="92" y="477" font-size="36" fill="${light?'#655E76':'#C3BBCE'}">${theme[0].toUpperCase()+theme.slice(1)} card style · Sample profile</text>
    <text x="92" y="553" font-size="25" letter-spacing="3" fill="${light?'#817895':'#9D91B3'}">CARD STYLE SAMPLE · ACTUAL APP</text></g>
    <rect x="150" y="623" width="942" height="1998" rx="88" fill="#09070D"/><rect x="159" y="632" width="924" height="1980" rx="78" fill="#37303F"/>
    <image x="171" y="645" width="900" height="1955.45" clip-path="url(#screen)" xlink:href="data:image/png;base64,${data}"/>
   </svg>`;
   const base=path.join(out,`${name}-${size}`);fs.writeFileSync(base+'.svg',svg);
   await sharp(Buffer.from(svg)).removeAlpha().png().toFile(base+'.png');
  }
 }
 console.log('Exported seven native card samples in both iPhone sizes.');
})();
