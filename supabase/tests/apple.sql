begin;
set local role service_role;
do $$
begin
  insert into public.taplead_apple_challenges values (repeat('a',64),now()+interval '5 minutes'),(repeat('b',64),now()-interval '1 minute');
  if not public.taplead_consume_apple_challenge(repeat('a',64)) then raise exception 'Valid challenge rejected'; end if;
  if public.taplead_consume_apple_challenge(repeat('a',64)) then raise exception 'Consumed challenge replay accepted'; end if;
  if public.taplead_consume_apple_challenge(repeat('b',64)) then raise exception 'Expired challenge accepted'; end if;
  if has_table_privilege('anon','public.taplead_apple_credentials','SELECT') or has_table_privilege('authenticated','public.taplead_apple_credentials','SELECT') then raise exception 'Credential disclosure'; end if;
  if has_function_privilege('anon','public.taplead_consume_apple_challenge(text)','EXECUTE') or has_function_privilege('authenticated','public.taplead_consume_apple_challenge(text)','EXECUTE') then raise exception 'Public challenge access'; end if;
end;
$$;
rollback;
