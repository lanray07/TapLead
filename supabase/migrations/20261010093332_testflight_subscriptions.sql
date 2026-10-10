-- Administrative rollout switches. Clients cannot enable purchases or sandbox access.
create table public.taplead_subscription_settings (
  singleton boolean primary key default true check (singleton),
  purchases_enabled boolean not null default false,
  sandbox_enabled boolean not null default false
);
alter table public.taplead_subscription_settings enable row level security;
revoke all on public.taplead_subscription_settings from public, anon, authenticated;
grant select on public.taplead_subscription_settings to service_role;
insert into public.taplead_subscription_settings(singleton) values (true);

create or replace function public.taplead_plan(p_owner uuid) returns jsonb
language sql stable security invoker set search_path='' as $$
  with settings as (
    select coalesce(bool_or(purchases_enabled),false) as purchases_enabled,
           coalesce(bool_or(sandbox_enabled),false) as sandbox_enabled
    from public.taplead_subscription_settings where singleton
  ), eligibility as (
    select exists(select 1 from public.taplead_entitlements e
      where e.owner=p_owner and not e.revoked
        and e.expires > extract(epoch from now())*1000
        and (e.environment='Production' or (s.sandbox_enabled and e.environment='Sandbox'))) as pro,
      s.purchases_enabled, s.sandbox_enabled
    from settings s
  )
  select jsonb_build_object('pro',pro,'cardLimit',case when pro then 20 else 1 end,
    'leadLimit',case when pro then 10000 else 50 end,
    'purchasesEnabled',purchases_enabled,'subscriptionTesting',sandbox_enabled)
  from eligibility;
$$;
