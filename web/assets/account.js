const url='https://qyflrgvolsiljpsghqku.supabase.co';
// Publishable key: has no permission to read TapLead tables or invoke private RPCs.
const key='sb_publishable_Ee1fCENfQ6g92jluvC_wRw_1Kv-onPt';
const fragment=new URLSearchParams(location.hash.slice(1)),token=fragment.get('access_token');
history.replaceState(null,'',location.pathname); // Remove tokens from history immediately.
const status=document.querySelector('#status'),title=document.querySelector('#title'),form=document.querySelector('#recovery');
if(fragment.get('error'))status.textContent='This link is invalid or has expired. Request a new email from TapLead.';
else if(token&&fragment.get('type')==='recovery'){
  title.textContent='Reset your password';status.textContent='Choose a password of at least 12 characters.';form.hidden=false;
  form.addEventListener('submit',async event=>{event.preventDefault();if(!form.reportValidity())return;const password=document.querySelector('#password').value;if(password!==document.querySelector('#confirm').value){status.textContent='The passwords must match.';return;}const button=form.querySelector('button');button.disabled=true;try{const response=await fetch(url+'/auth/v1/user',{method:'PUT',headers:{apikey:key,Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({password})});if(!response.ok)throw Error('This link may have expired. Request a new recovery email.');await fetch(url+'/auth/v1/logout?scope=global',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+token}});form.reset();form.hidden=true;title.textContent='Password updated';status.textContent='Return to TapLead and sign in with your new password.';}catch(error){status.textContent=error.message;button.disabled=false;}});
}else if(token){
  fetch(url+'/auth/v1/user',{headers:{apikey:key,Authorization:'Bearer '+token}}).then(async response=>{
    if(!response.ok)throw Error('This link is invalid or has expired. Request a new verification email.');
    const user=await response.json();if(!user.email_confirmed_at)throw Error('Your email still needs verification.');
    title.textContent='Email verified';status.textContent='Return to TapLead and sign in to your account.';
    await fetch(url+'/auth/v1/logout?scope=local',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+token}});
  }).catch(error=>status.textContent=error.message);
}
