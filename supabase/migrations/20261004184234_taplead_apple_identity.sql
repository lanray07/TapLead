create table public.taplead_apple_challenges (
  hash text primary key check(length(hash)=64), expires timestamptz not null
);
create table public.taplead_apple_credentials (
  owner uuid primary key references auth.users(id) on delete cascade,
  subject text not null unique, sealed_refresh text not null
);
alter table public.taplead_apple_challenges enable row level security;
alter table public.taplead_apple_credentials enable row level security;
revoke all on public.taplead_apple_challenges,public.taplead_apple_credentials from public,anon,authenticated;
grant all on public.taplead_apple_challenges,public.taplead_apple_credentials to service_role;
create function public.taplead_consume_apple_challenge(p_hash text) returns boolean
language sql security invoker set search_path='' as $$
  with consumed as (delete from public.taplead_apple_challenges where hash=p_hash and expires>now() returning hash)
  select exists(select 1 from consumed);
$$;
revoke all on function public.taplead_consume_apple_challenge(text) from public,anon,authenticated;
grant execute on function public.taplead_consume_apple_challenge(text) to service_role;
