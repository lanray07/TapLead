-- Run against an empty staging project or during initial production setup.
-- All synthetic identities and records are rolled back; no receipt or Pro claim is fabricated.
begin;
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
begin
  insert into auth.users(id) values(a),(b);
  perform set_config('taplead.test_a',a::text,true);
  perform set_config('taplead.test_b',b::text,true);
  perform set_config('taplead.test_card',gen_random_uuid()::text,true);
end;
$$;
set local role service_role;
do $$
declare a uuid:=current_setting('taplead.test_a')::uuid;
  b uuid:=current_setting('taplead.test_b')::uuid;
  c uuid:=current_setting('taplead.test_card')::uuid;
  card jsonb; lead jsonb;
begin
  if (public.taplead_plan(a)->>'pro')::boolean then raise exception 'Unexpected Pro entitlement'; end if;
  card:=jsonb_build_object('id',c,'name','Temporary test','theme','Executive','published',true,'cornerImageKind','Logo');
  perform public.taplead_save(a,'card',card);
  begin
    perform public.taplead_save(a,'card',card||jsonb_build_object('id',gen_random_uuid()));
    raise exception 'Card quota did not reject';
  exception when sqlstate 'PT403' then null; end;
  begin
    perform public.taplead_save(b,'card',card);
    raise exception 'Ownership did not reject';
  exception when sqlstate 'PT404' then null; end;
  begin
    perform public.taplead_save(a,'card',card||'{"customBackground":"ffffff"}'::jsonb);
    raise exception 'Premium appearance did not reject';
  exception when sqlstate 'PT403' then null; end;
  -- Expired Pro owners may still unpublish a card using a saved premium appearance.
  perform public.taplead_save(a,'card',card||'{"published":false,"customBackground":"ffffff"}'::jsonb);
  perform public.taplead_save(a,'card',card);
  begin
    perform public.taplead_image(b,c,'Logo','AA==');
    raise exception 'Media ownership did not reject';
  exception when sqlstate 'PT404' then null; end;
  perform public.taplead_image(a,c,'Logo','AA==');
  if not exists(select 1 from public.taplead_media where card_id=c) then raise exception 'Media write failed'; end if;
  perform public.taplead_image(a,c,null,null);
  if exists(select 1 from public.taplead_media where card_id=c) then raise exception 'Media delete failed'; end if;
  lead:=jsonb_build_object('id',gen_random_uuid(),'cardID',c,'consent',false);
  begin
    perform public.taplead_capture(c,lead);
    raise exception 'Missing consent did not reject';
  exception when sqlstate 'PT400' then null; end;
  begin
    perform public.taplead_save(b,'lead',lead);
    raise exception 'Foreign card lead did not reject';
  exception when sqlstate 'PT400' then null; end;
  for i in 1..50 loop
    perform public.taplead_save(a,'lead',jsonb_build_object('id',gen_random_uuid(),'cardID',c));
  end loop;
  begin
    perform public.taplead_capture(c,lead||'{"consent":true}'::jsonb);
    raise exception 'Public lead quota did not reject';
  exception when sqlstate 'PT403' then null; end;
  select data into lead from public.taplead_leads where owner=a limit 1;
  perform public.taplead_save(a,'lead',lead||'{"notes":"Updated at quota"}'::jsonb);
  insert into public.taplead_sessions(hash,owner,expires) values(repeat('0',64),a,now()-interval '1 minute');
  if exists(select 1 from public.taplead_sessions where hash=repeat('0',64) and expires>now()) then raise exception 'Expired session accepted'; end if;
  if has_table_privilege('anon','public.taplead_cards','SELECT') or
     has_table_privilege('authenticated','public.taplead_leads','SELECT') or
     has_function_privilege('anon','public.taplead_save(uuid,text,jsonb)','EXECUTE') then
    raise exception 'Public data privilege leak';
  end if;
end;
$$;
reset role;
do $$
declare a uuid:=current_setting('taplead.test_a')::uuid;
begin
  insert into public.taplead_sessions(hash,owner,expires) values(repeat('1',64),a,now()+interval '1 day');
  update auth.users set encrypted_password='temporary-password-reset-test' where id=a;
  if exists(select 1 from public.taplead_sessions where owner=a) then raise exception 'Password reset did not revoke sessions'; end if;
  delete from auth.users where id=a;
  if exists(select 1 from public.taplead_cards where owner=a) or
     exists(select 1 from public.taplead_leads where owner=a) or
     exists(select 1 from public.taplead_sessions where owner=a) then
    raise exception 'Account deletion did not cascade';
  end if;
end;
$$;
rollback;
select 'Ownership, quotas, consent, expired sessions, private API privileges and deletion cascades passed; fixtures rolled back.' as result;
