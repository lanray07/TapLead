-- Structural database checks only; no genuine receipt or purchase acceptance claim.
begin;
update public.taplead_subscription_settings set purchases_enabled=false,sandbox_enabled=false where singleton;
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
begin
 insert into auth.users(id) values(a),(b);
 perform set_config('taplead.test_a',a::text,true);perform set_config('taplead.test_b',b::text,true);
end;
$$;
set local role service_role;
do $$
declare a uuid:=current_setting('taplead.test_a')::uuid; b uuid:=current_setting('taplead.test_b')::uuid;
 r jsonb:=jsonb_build_object('owner',a,'environment','Sandbox','original_id','123456789','product','com.taplead.pro.monthly','expires',9999999999999,'revoked',false,'signed_date',100);
begin
 perform public.taplead_store_transaction(r);
 if (public.taplead_plan(a)->>'pro')::boolean then raise exception 'Sandbox granted Production Pro'; end if;
 r:=r||jsonb_build_object('environment','Production','revoked',true,'signed_date',200);
 perform public.taplead_store_transaction(r);
 if (select count(*) from public.taplead_entitlements where owner=a)<>2 then raise exception 'Receipt environments collided'; end if;
 perform public.taplead_store_transaction(r||jsonb_build_object('revoked',false,'signed_date',150));
 if (public.taplead_plan(a)->>'pro')::boolean then raise exception 'Replay undid revocation'; end if;
 begin
  perform public.taplead_store_transaction(r||jsonb_build_object('owner',b,'signed_date',300));
  raise exception 'Account takeover accepted';
 exception when sqlstate 'PT403' then null;end;
 if has_function_privilege('anon','public.taplead_store_transaction(jsonb)','EXECUTE') or has_function_privilege('authenticated','public.taplead_store_transaction(jsonb)','EXECUTE') then raise exception 'Public receipt writes enabled'; end if;
end;
$$;
rollback;
