-- Password material and administrator membership are never in the exposed schema.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create extension if not exists pgcrypto with schema extensions;
create table private.group_credentials (
  singleton boolean primary key default true check (singleton),
  password_hash text not null
);
create table private.admins (user_id uuid primary key references auth.users(id) on delete cascade);
create table private.join_attempts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_start timestamptz not null default now(),
  attempts integer not null default 0
);
alter table private.group_credentials enable row level security;
alter table private.admins enable row level security;
alter table private.join_attempts enable row level security;
revoke all on all tables in schema private from public, anon, authenticated;

create function private.is_admin() returns boolean language sql stable security definer
set search_path = '' as $$
  select exists (select 1 from private.admins where user_id = (select auth.uid()));
$$;
revoke all on function private.is_admin() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.is_admin() to authenticated;

create table public.installations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) between 1 and 80),
  platform text not null check (platform in ('android', 'windows', 'linux', 'web')),
  device_name text not null check (length(btrim(device_name)) between 1 and 120),
  app_version text not null check (length(app_version) between 1 and 40),
  receiving boolean not null default true,
  created_at timestamptz not null default now(),
  last_heartbeat timestamptz not null default now(),
  revoked_at timestamptz
);
alter table public.installations enable row level security;
revoke all on public.installations from public, anon, authenticated;
grant select on public.installations to authenticated;
create policy read_own_or_admin on public.installations for select to authenticated
using ((user_id = (select auth.uid()) and revoked_at is null) or (select private.is_admin()));

create function public.join_installation(
  p_password text, p_display_name text, p_platform text, p_device_name text,
  p_app_version text, p_receiving boolean default true
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := auth.uid();
  attempt private.join_attempts;
  secret text;
  result public.installations;
begin
  if caller is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, false) is not true then
    raise insufficient_privilege using message = 'An installation session is required';
  end if;
  if p_password is null or octet_length(p_password) not between 1 and 72
    or p_display_name is null or length(btrim(p_display_name)) not between 1 and 80
    or p_device_name is null or length(btrim(p_device_name)) not between 1 and 120
    or p_app_version is null or length(p_app_version) not between 1 and 40
    or p_platform is null or p_platform not in ('android', 'windows', 'linux', 'web')
    or p_receiving is null then
    raise invalid_parameter_value using message = 'Invalid installation details';
  end if;
  -- Serialize attempts per identity; return errors instead of raising so attempts commit.
  insert into private.join_attempts(user_id) values (caller) on conflict do nothing;
  select * into attempt from private.join_attempts where user_id = caller for update;
  if attempt.window_start < now() - interval '15 minutes' then
    update private.join_attempts set attempts = 0, window_start = now() where user_id = caller;
    attempt.attempts := 0;
  end if;
  if attempt.attempts >= 5 then return jsonb_build_object('error', 'rate_limited'); end if;
  update private.join_attempts set attempts = attempts + 1 where user_id = caller;
  select password_hash into secret from private.group_credentials where singleton;
  if secret is null or extensions.crypt(p_password, secret) <> secret then
    return jsonb_build_object('error', 'join_denied');
  end if;
  insert into public.installations(user_id, display_name, platform, device_name, app_version, receiving)
  values(caller, btrim(p_display_name), p_platform, btrim(p_device_name), p_app_version, p_receiving)
  on conflict(user_id) do update set
    display_name = excluded.display_name, platform = excluded.platform,
    device_name = excluded.device_name, app_version = excluded.app_version,
    receiving = excluded.receiving, revoked_at = null, last_heartbeat = now()
  returning * into result;
  return jsonb_build_object('installation', to_jsonb(result));
end;
$$;
revoke all on function public.join_installation(text,text,text,text,text,boolean) from public, anon;
grant execute on function public.join_installation(text,text,text,text,text,boolean) to authenticated;

create function public.set_receiving(p_receiving boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare result public.installations;
begin
  if p_receiving is null then raise invalid_parameter_value; end if;
  update public.installations set receiving = p_receiving, last_heartbeat = now()
  where user_id = auth.uid() and revoked_at is null returning * into result;
  if not found then raise insufficient_privilege using message = 'Active installation required'; end if;
  return to_jsonb(result);
end;
$$;
revoke all on function public.set_receiving(boolean) from public, anon;
grant execute on function public.set_receiving(boolean) to authenticated;

create function public.revoke_installation(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_admin() then raise insufficient_privilege using message = 'Administrator required'; end if;
  update public.installations set revoked_at = now() where id = p_id;
end;
$$;
revoke all on function public.revoke_installation(uuid) from public, anon;
grant execute on function public.revoke_installation(uuid) to authenticated;
