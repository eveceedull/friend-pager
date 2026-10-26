-- Short-lived transport rows only: no alert history, acknowledgments or retries.
create table public.alert_deliveries (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  sender_installation_id uuid not null references public.installations(id) on delete cascade,
  sender_name text not null,
  created_at timestamptz not null,
  expires_at timestamptz not null,
  unique(alert_id, recipient_user_id)
);
create index alert_deliveries_expiry on public.alert_deliveries(expires_at);
create index alert_deliveries_recipient on public.alert_deliveries(recipient_user_id);
alter table public.alert_deliveries enable row level security;
revoke all on public.alert_deliveries from public, anon, authenticated;
grant select on public.alert_deliveries to authenticated;
create policy live_own_delivery on public.alert_deliveries for select to authenticated
using (
  recipient_user_id = (select auth.uid()) and expires_at > now()
  and exists (select 1 from public.installations i
    where i.user_id = (select auth.uid()) and i.revoked_at is null and i.receiving
      and i.id <> sender_installation_id)
);
alter publication supabase_realtime add table public.alert_deliveries;

create function public.send_alert() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  sender public.installations;
  alert uuid := gen_random_uuid();
  sent_at timestamptz := clock_timestamp();
begin
  select * into sender from public.installations
  where user_id = auth.uid() and revoked_at is null for share;
  if not found then
    raise insufficient_privilege using message = 'Active installation required';
  end if;
  insert into public.alert_deliveries(alert_id, recipient_user_id,
    sender_installation_id, sender_name, created_at, expires_at)
  select alert, i.user_id, sender.id, sender.display_name, sent_at, sent_at + interval '20 seconds'
  from public.installations i
  where i.revoked_at is null and i.receiving and i.user_id <> sender.user_id;
  -- Submission only, deliberately no recipient counts or delivery guarantees.
  return jsonb_build_object('id', alert, 'expires_at', sent_at + interval '20 seconds');
end;
$$;
revoke all on function public.send_alert() from public, anon;
grant execute on function public.send_alert() to authenticated;

-- Check live authorization/expiry again before presentation, including events
-- already in transit when receiving was disabled or an installation was revoked.
-- Remaining lifetime comes from the server, not the device's wall clock.
create function public.get_live_alert(p_id uuid, p_not_before timestamptz default '-infinity') returns jsonb
language sql security invoker set search_path = '' as $$
  select jsonb_build_object('id', id, 'sender_installation_id', sender_installation_id,
    'sender_name', sender_name,
    'remaining_ms', greatest(0, floor(extract(epoch from (expires_at - clock_timestamp())) * 1000)))
  from public.alert_deliveries where id = p_id and expires_at > clock_timestamp() and created_at >= p_not_before;
$$;
revoke all on function public.get_live_alert(uuid,timestamptz) from public, anon;
grant execute on function public.get_live_alert(uuid,timestamptz) to authenticated;

create function private.purge_expired_alerts() returns void
language sql security definer set search_path = '' as $$
  delete from public.alert_deliveries where expires_at <= clock_timestamp();
$$;
revoke all on function private.purge_expired_alerts() from public, anon, authenticated;
create extension if not exists pg_cron;
select cron.schedule('purge-expired-alerts', '* * * * *', 'select private.purge_expired_alerts()');

-- Establish a new receive boundary from the same clock used to timestamp alerts.
create function public.paging_cursor() returns timestamptz
language sql security invoker set search_path = '' as $$ select clock_timestamp(); $$;
revoke all on function public.paging_cursor() from public, anon;
grant execute on function public.paging_cursor() to authenticated;
