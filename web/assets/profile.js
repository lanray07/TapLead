const api='https://qyflrgvolsiljpsghqku.supabase.co/functions/v1/taplead';
const params=new URLSearchParams(location.search),id=params.get('id');
const source=['qr','nfc','email','website','event','social','direct'].includes(params.get('source'))?params.get('source'):'direct';
const profile=document.querySelector('#profile');
function node(tag,value,className){const n=document.createElement(tag);if(value)n.textContent=value;if(className)n.className=className;return n;}
function link(label,href,className){const a=node('a',label,className);a.href=href;a.rel='noopener noreferrer';return a;}
function actionPath(tail){return `${api}/p/${id}/${tail}?source=${source}`;}
async function load(){
  try{
    if(!/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(id||''))throw Error('Open a complete TapLead link shared with you.');
    const response=await fetch(`${api}/p/${id}?source=${source}`,{cache:'no-store'}),c=await response.json();
    if(!response.ok)throw Error(c.error||'This profile is unavailable.');
    document.title=`${c.name} · TapLead`;
    const css=node('link');css.rel='stylesheet';css.href=actionPath('theme.css');document.head.append(css);
    profile.replaceChildren();profile.className='';
    const cover=node('div',null,'cover');cover.append(node('span',c.persona),node('b','Every introduction.\nA new possibility.'));
    if(c.publicImageAvailable){const picture=node('img');picture.src=actionPath('image');picture.alt=c.cornerImageKind==='Logo'?'Company logo':'Profile photo';picture.width=64;picture.height=64;picture.className=`corner-image ${{'Top left':'top-left','Top right':'top-right','Bottom left':'bottom-left','Bottom right':'bottom-right'}[c.cornerImagePosition]||'top-right'} ${c.cornerImageKind==='Logo'?'logo':'photo'}`;cover.classList.add('has-image');cover.append(picture);}
    const identity=node('div',null,'identity'),avatar=node('div',c.name.split(' ').map(p=>p[0]).slice(0,2).join(''),'avatar');avatar.setAttribute('aria-hidden','true');
    identity.append(avatar,node('h1',c.preferredName||c.name),node('p',[c.title,c.company].filter(Boolean).join(' · ')),node('p',c.headline,'headline'));
    if(c.location)identity.append(node('p',c.location,'muted'));
    identity.append(link('Save Contact ↓',actionPath('contact.vcf'),'primary'));
    const labels={website:'Website',portfolio:'Portfolio',booking:'Book a meeting',cv:'View CV'};
    const primary=c.primaryAction||{Sales:'Book a meeting',Recruiting:c.cv?'View CV':'Portfolio',Event:'Website'}[c.networkingMode],field=Object.keys(labels).find(key=>labels[key]===primary);
    if(field&&c[field])identity.append(link((c.primaryActionLabel||primary)+' ↗',actionPath('go/'+field),'primary'));
    for(const section of c.sectionOrder){
      if(section==='About'&&c.bio)identity.append(node('p',c.bio,'bio'));
      if(section==='Contact'){const contacts=node('div',null,'links');if(c.email)contacts.append(link('Email','mailto:'+c.email));if(c.phone)contacts.append(link('Call','tel:'+c.phone.replace(/[^+\d]/g,'')));identity.append(contacts);}
      if(section==='Links'){const links=node('div',null,'links');for(const key of Object.keys(labels))if(c[key])links.append(link(labels[key]+' ↗',actionPath('go/'+key)));for(const social of c.socials||[]){try{const url=new URL(social.url);if(url.protocol==='https:'&&!url.username&&!url.password)links.append(link(social.service+' ↗',url.href));}catch{/* Ignore incomplete link drafts. */}}identity.append(links);}
    }
    const details=node('details'),form=node('form'),summary=node('summary','Share your details ↗');
    form.noValidate=false;
    for(const [name,title,type,max] of [['name','Name','text',120],['email','Email','email',254],['phone','Phone','tel',60],['company','Company','text',120],['role','Role','text',120],['interest','Interested in','text',500],['message','Message','text',2000]]){const label=node('label',title),input=node(name==='message'?'textarea':'input');input.name=name;input.maxLength=max;if(name!=='message')input.type=type;input.required=name==='name';input.autocomplete={name:'name',email:'email',phone:'tel',company:'organization',role:'organization-title'}[name]||'off';label.append(input);form.append(label);}
    const trap=node('input');trap.name='website';trap.tabIndex=-1;trap.className='trap';trap.autocomplete='off';trap.setAttribute('aria-hidden','true');form.append(trap);
    const consentLabel=node('label',null,'consent'),consent=node('input');consent.type='checkbox';consent.name='consent';consent.required=true;consentLabel.append(consent,node('span',`I agree to share these details with ${c.name} so they can contact me about my enquiry.`));form.append(consentLabel);
    const button=node('button','Share my details','primary');button.type='submit';const message=node('p','Please provide an email address or phone number.','muted');message.setAttribute('role','status');form.append(message,button);
    form.addEventListener('submit',async event=>{event.preventDefault();if(!form.reportValidity())return;const data=Object.fromEntries(new FormData(form));if(!data.email&&!data.phone){message.textContent='Please provide an email address or phone number.';return;}button.disabled=true;try{const r=await fetch(`${api}/p/${id}/leads`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({...data,consent:consent.checked,source})});const result=await r.json();if(!r.ok)throw Error(result.error||'Please try again later.');message.textContent=result.message;form.querySelectorAll('input,textarea,button').forEach(n=>n.disabled=true);}catch(error){message.textContent=error.message;button.disabled=false;}});
    details.append(summary,node('p',`Introduce yourself to ${c.preferredName||c.name}. Your details are shared only when you submit this form.`,'muted'),form);identity.append(details);profile.append(cover,identity);
  }catch(error){profile.replaceChildren(node('h1','Profile unavailable'),node('p',error.message));}
  finally{profile.setAttribute('aria-busy','false');}
}
load();
