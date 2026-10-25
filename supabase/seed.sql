-- PUBLIC LOCAL FIXTURE ONLY. Never deploy this seed or password to production.
insert into private.group_credentials(singleton, password_hash)
values (true, extensions.crypt('local-group-password', extensions.gen_salt('bf', 10)))
on conflict (singleton) do update set password_hash = excluded.password_hash;
