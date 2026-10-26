-- Public local-development fixture password, matching compose.yaml.
-- Derived from Supabase self-hosted/v0.8.3 docker/volumes/db/roles.sql.
\getenv pgpass POSTGRES_PASSWORD
alter user authenticator with password :'pgpass';
alter user supabase_auth_admin with password :'pgpass';
alter user supabase_admin with password :'pgpass';
alter user postgres with password :'pgpass';
create schema if not exists _realtime authorization supabase_admin;
do $$ begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;
