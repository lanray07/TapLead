-- Structural fixture tests, rolled back; these do not prove a real Apple purchase.
begin;
update public.taplead_subscription_settings set purchases_enabled=true,sandbox_enabled=true where singleton;
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
begin
  insert into auth.users(id) values(a),(b);
  perform set_config('taplead.test_a',a::text,true);
  perform set_config('taplead.test_b',b::text,true);
end;
$$;
set local role service_role;
do $$
declare a uuid:=current_setting('taplead.test_a')::uuid; b uuid:=current_setting('taplead.test_b')::uuid;
  r jsonb:=jsonb_build_object('owner',a,'environment','Sandbox','original_id','987654321',
    'product','com.taplead.pro.monthly','expires',1,'revoked',false,'signed_date',100);
begin
  if not (public.taplead_plan(b)->>'purchasesEnabled')::boolean or (public.taplead_plan(b)->>'pro')::boolean then
    raise exception 'Purchase availability incorrectly granted Free user Pro';
  end if;
  perform public.taplead_store_transaction(r);
  if (public.taplead_plan(a)->>'pro')::boolean then raise exception 'Expired Sandbox receipt granted Pro'; end if;
  r:=r||jsonb_build_object('expires',9999999999999,'signed_date',200);
  perform public.taplead_store_transaction(r);
  if not (public.taplead_plan(a)->>'pro')::boolean
    or (public.taplead_plan(a)->>'cardLimit')::int<>20
    or (public.taplead_plan(a)->>'leadLimit')::int<>10000 then
    raise exception 'Active Sandbox receipt did not unlock Pro test quotas';
  end if;
  if exists(select 1 from public.taplead_entitlements where owner=a and environment='Production') then
    raise exception 'Sandbox purchase created a Production record';
  end if;
  perform public.taplead_store_transaction(r||jsonb_build_object('revoked',true,'signed_date',300));
  perform public.taplead_store_transaction(r||jsonb_build_object('signed_date',250));
  if (public.taplead_plan(a)->>'pro')::boolean then raise exception 'Stale replay undid Sandbox refund'; end if;
  perform public.taplead_store_transaction(r||jsonb_build_object('signed_date',400));
  if has_table_privilege('anon','public.taplead_subscription_settings','SELECT')
    or has_table_privilege('authenticated','public.taplead_subscription_settings','UPDATE')
    or has_table_privilege('service_role','public.taplead_subscription_settings','UPDATE') then
    raise exception 'Subscription rollout settings accessible to an unprivileged caller';
  end if;
end;
$$;
reset role;
update public.taplead_subscription_settings set sandbox_enabled=false where singleton;
set local role service_role;
do $$
declare a uuid:=current_setting('taplead.test_a')::uuid;
begin
  if (public.taplead_plan(a)->>'pro')::boolean then raise exception 'Disabled testing still grants Sandbox Pro'; end if;
  perform public.taplead_store_transaction(jsonb_build_object('owner',a,'environment','Production','original_id','987654321',
    'product','com.taplead.pro.yearly','expires',9999999999999,'revoked',false,'signed_date',500));
  if not (public.taplead_plan(a)->>'pro')::boolean then raise exception 'Production Pro lost when Sandbox was disabled'; end if;
  if (select count(*) from public.taplead_entitlements where owner=a)<>2 then raise exception 'Receipt environments collided'; end if;
end;
$$;
rollback;
