-- Supabase recovery changes the managed password. Revoke opaque app sessions too,
-- so a password reset cannot leave a stolen TapLead session valid for 30 days.
create schema if not exists taplead_private;
revoke all on schema taplead_private from public,anon,authenticated;
create function taplead_private.revoke_password_sessions() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  delete from public.taplead_sessions where owner=new.id;
  return new;
end;
$$;
revoke all on function taplead_private.revoke_password_sessions() from public,anon,authenticated;
create trigger taplead_password_session_revocation
  after update of encrypted_password on auth.users
  for each row when (old.encrypted_password is distinct from new.encrypted_password)
  execute function taplead_private.revoke_password_sessions();
