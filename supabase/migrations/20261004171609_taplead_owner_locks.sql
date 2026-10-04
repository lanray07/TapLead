create or replace function public.taplead_save(p_owner uuid,p_kind text,p_data jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare p_id uuid := (p_data->>'id')::uuid; existing_owner uuid; plan jsonb; n integer;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_owner::text,0));

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

create or replace function public.taplead_capture(p_card uuid,p_data jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare c public.taplead_cards%rowtype;
begin
  select * into c from public.taplead_cards where id=p_card;
  if not found then raise exception 'Card unavailable' using errcode='PT404'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(c.owner::text,0));
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

create or replace function public.taplead_image(p_owner uuid,p_card uuid,p_kind text,p_pixels text) returns void
language plpgsql security invoker set search_path='' as $$
declare c public.taplead_cards%rowtype;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_owner::text,0));
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