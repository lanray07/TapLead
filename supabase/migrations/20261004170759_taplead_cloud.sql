-- The Edge API is the only data gateway. Mobile and anonymous clients have no
-- table/function privileges; an opaque, revocable session authenticates each API call.
create table public.taplead_sessions (
  hash text primary key check (length(hash)=64),
  owner uuid not null references auth.users(id) on delete cascade,
  expires timestamptz not null
);
create index taplead_sessions_owner on public.taplead_sessions(owner);
create table public.taplead_cards (
  id uuid primary key,
  owner uuid not null references auth.users(id) on delete cascade,
  data jsonb not null check (jsonb_typeof(data)='object')
);
create index taplead_cards_owner on public.taplead_cards(owner);
create table public.taplead_leads (
  id uuid primary key,
  owner uuid not null references auth.users(id) on delete cascade,
  data jsonb not null check (jsonb_typeof(data)='object')
);
create index taplead_leads_owner on public.taplead_leads(owner);
create table public.taplead_media (
  card_id uuid primary key references public.taplead_cards(id) on delete cascade,
  kind text not null check (kind in ('Photo','Logo')),
  pixels text not null check (length(pixels)<=2796204)
);
create table public.taplead_events (
  id bigint generated always as identity primary key,
  card_id uuid not null references public.taplead_cards(id) on delete cascade,
  kind text not null check (kind in ('profile_view','vcard_download','cta_click','booking_click','lead_submission')),
  source text not null check (source in ('qr','nfc','email','website','event','social','direct')),
  created bigint not null
);
create index taplead_events_card_date on public.taplead_events(card_id,created);
create table public.taplead_entitlements (
  original_id text primary key,
  owner uuid not null references auth.users(id) on delete cascade,
  product text not null check (product in ('com.taplead.pro.monthly','com.taplead.pro.yearly')),
  expires bigint not null,
  revoked boolean not null,
  signed_date bigint not null,
  environment text not null check (environment in ('Production','Sandbox'))
);
create index taplead_entitlements_owner on public.taplead_entitlements(owner);
create table public.taplead_rate_buckets (
  key text primary key,
  count integer not null,
  until timestamptz not null
);
create index taplead_rate_buckets_until on public.taplead_rate_buckets(until);

alter table public.taplead_sessions enable row level security;
alter table public.taplead_cards enable row level security;
alter table public.taplead_leads enable row level security;
alter table public.taplead_media enable row level security;
alter table public.taplead_events enable row level security;
alter table public.taplead_entitlements enable row level security;
alter table public.taplead_rate_buckets enable row level security;
revoke all on public.taplead_sessions, public.taplead_cards, public.taplead_leads,
  public.taplead_media, public.taplead_events, public.taplead_entitlements,
  public.taplead_rate_buckets from public, anon, authenticated;
grant all on public.taplead_sessions, public.taplead_cards, public.taplead_leads,
  public.taplead_media, public.taplead_events, public.taplead_entitlements,
  public.taplead_rate_buckets to service_role;
grant usage, select on sequence public.taplead_events_id_seq to service_role;

create function public.taplead_plan(p_owner uuid) returns jsonb
language sql stable security invoker set search_path='' as $$
  select jsonb_build_object('pro',pro,'cardLimit',case when pro then 20 else 1 end,
    'leadLimit',case when pro then 10000 else 50 end)
  from (select exists(select 1 from public.taplead_entitlements
    where owner=p_owner and environment='Production' and not revoked
    and expires > extract(epoch from now())*1000) as pro) p;
$$;

-- Lock one owner for every quota-changing write, including anonymous capture.
-- Concurrent invocations cannot overshoot a free or Pro quota.
create function public.taplead_save(p_owner uuid,p_kind text,p_data jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare p_id uuid := (p_data->>'id')::uuid; existing_owner uuid; plan jsonb; n integer;
begin
  perform id from auth.users where id=p_owner for update;
  if not found then raise exception 'Unauthenticated' using errcode='PT401'; end if;
  plan := public.taplead_plan(p_owner);
  if p_kind='card' then
    select owner into existing_owner from public.taplead_cards where id=p_id;
    if existing_owner is not null and existing_owner<>p_owner then
      raise exception 'Card not found' using errcode='PT404';
    end if;
    if coalesce((p_data->>'published')::boolean,false) and not (plan->>'pro')::boolean
      and (p_data ? 'customBackground' or p_data ? 'typography' or p_data ? 'primaryAction'
        or p_data ? 'primaryActionLabel' or p_data->>'theme' not in ('Minimal','Executive')) then
      raise exception 'Advanced appearance requires Pro' using errcode='PT403';
    end if;
    select count(*) into n from public.taplead_cards where owner=p_owner;
    if existing_owner is null and n >= (plan->>'cardLimit')::integer then
      raise exception 'Your plan card limit has been reached' using errcode='PT403';
    end if;
    insert into public.taplead_cards(id,owner,data) values(p_id,p_owner,p_data)
      on conflict(id) do update set data=excluded.data where taplead_cards.owner=p_owner;
    if not found then raise exception 'Card not found' using errcode='PT404'; end if;
  elsif p_kind='lead' then
    if p_data->>'cardID' is not null and not exists(select 1 from public.taplead_cards
      where id=(p_data->>'cardID')::uuid and owner=p_owner) then
      raise exception 'Select a card you own' using errcode='PT400';
    end if;
    select owner into existing_owner from public.taplead_leads where id=p_id;
    if existing_owner is not null and existing_owner<>p_owner then
      raise exception 'Lead not found' using errcode='PT404';
    end if;
    select count(*) into n from public.taplead_leads where owner=p_owner;
    if existing_owner is null and n >= (plan->>'leadLimit')::integer then
      raise exception 'Your plan lead limit has been reached' using errcode='PT403';
    end if;
    insert into public.taplead_leads(id,owner,data) values(p_id,p_owner,p_data)
      on conflict(id) do update set data=excluded.data where taplead_leads.owner=p_owner;
    if not found then raise exception 'Lead not found' using errcode='PT404'; end if;
  else raise exception 'Invalid record kind' using errcode='PT400'; end if;
  return p_data;
end;
$$;

create function public.taplead_capture(p_card uuid,p_data jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare c public.taplead_cards%rowtype;
begin
  select * into c from public.taplead_cards where id=p_card;
  if not found then raise exception 'Card unavailable' using errcode='PT404'; end if;
  perform id from auth.users where id=c.owner for update;
  -- Re-read after the owner lock so unpublish/delete serializes with capture.
  select * into c from public.taplead_cards where id=p_card;
  if not found or not coalesce((c.data->>'published')::boolean,false) then
    raise exception 'Card unavailable' using errcode='PT404';
  end if;
  if (p_data->>'cardID')::uuid<>p_card or not coalesce((p_data->>'consent')::boolean,false) then
    raise exception 'Consent required' using errcode='PT400';
  end if;
  return public.taplead_save(c.owner,'lead',p_data);
end;
$$;

create function public.taplead_rate(p_key text,p_limit integer,p_seconds integer) returns boolean
language plpgsql security invoker set search_path='' as $$
declare hits integer;
begin
  delete from public.taplead_rate_buckets where until<now();
  insert into public.taplead_rate_buckets(key,count,until)
    values(p_key,1,now()+make_interval(secs=>p_seconds))
    on conflict(key) do update set count=taplead_rate_buckets.count+1
    returning count into hits;
  return hits<=p_limit;
end;
$$;

revoke all on function public.taplead_plan(uuid), public.taplead_save(uuid,text,jsonb),
  public.taplead_capture(uuid,jsonb), public.taplead_rate(text,integer,integer)
  from public,anon,authenticated;
grant execute on function public.taplead_plan(uuid), public.taplead_save(uuid,text,jsonb),
  public.taplead_capture(uuid,jsonb), public.taplead_rate(text,integer,integer) to service_role;

create function public.taplead_image(p_owner uuid,p_card uuid,p_kind text,p_pixels text) returns void
language plpgsql security invoker set search_path='' as $$
declare c public.taplead_cards%rowtype;
begin
  perform id from auth.users where id=p_owner for update;
  select * into c from public.taplead_cards where id=p_card and owner=p_owner for update;
  if not found then raise exception 'Card not found' using errcode='PT404'; end if;
  if p_pixels is null then
    delete from public.taplead_media where card_id=p_card;
  else
    if p_kind is null or c.data->>'cornerImageKind'<>p_kind then
      raise exception 'Update the card image choice before uploading' using errcode='PT409';
    end if;
    insert into public.taplead_media values(p_card,p_kind,p_pixels)
      on conflict(card_id) do update set kind=excluded.kind,pixels=excluded.pixels;
  end if;
end;
$$;
revoke all on function public.taplead_image(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.taplead_image(uuid,uuid,text,text) to service_role;
