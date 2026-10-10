-- Supabase default grants include service_role writes; rollout settings are admin-only.
revoke all on public.taplead_subscription_settings from service_role;
grant select on public.taplead_subscription_settings to service_role;
