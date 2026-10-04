-- Separate receipt environments; a Sandbox record never overwrites Production.
alter table public.taplead_entitlements drop constraint taplead_entitlements_pkey;
alter table public.taplead_entitlements add primary key(environment,original_id);
create function public.taplead_store_transaction(p_data jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare prior public.taplead_entitlements; target uuid := (p_data->>'owner')::uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_data->>'environment'||':'||p_data->>'original_id',1));
  select * into prior from public.taplead_entitlements where environment=p_data->>'environment' and original_id=p_data->>'original_id';
  if found then
    if prior.owner<>target then raise exception 'Subscription account mismatch' using errcode='PT403'; end if;
    if prior.signed_date >= (p_data->>'signed_date')::bigint then return public.taplead_plan(target); end if;
  end if;
  insert into public.taplead_entitlements(environment,original_id,owner,product,expires,revoked,signed_date)
  values(p_data->>'environment',p_data->>'original_id',target,p_data->>'product',(p_data->>'expires')::bigint,(p_data->>'revoked')::boolean,(p_data->>'signed_date')::bigint)
  on conflict(environment,original_id) do update set product=excluded.product,expires=excluded.expires,revoked=excluded.revoked,signed_date=excluded.signed_date;
  return public.taplead_plan(target);
end;
$$;
revoke all on function public.taplead_store_transaction(jsonb) from public,anon,authenticated;
grant execute on function public.taplead_store_transaction(jsonb) to service_role;
