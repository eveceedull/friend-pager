"""Local Compose initialization. No Docker socket, CLI, host SDK or SaaS access."""
import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.request

import psycopg


def local_key(role):
    def encode(value):
        return base64.urlsafe_b64encode(json.dumps(value, separators=(',', ':')).encode()).rstrip(b'=')
    data = encode({'alg': 'HS256', 'typ': 'JWT'}) + b'.' + encode({
        'role': role, 'iss': 'friend-pager-local-compose', 'aud': 'authenticated',
        'iat': int(time.time()), 'exp': 4102444800})
    signature = hmac.new(os.environ['JWT_SECRET'].encode(), data, hashlib.sha256).digest()
    return (data + b'.' + base64.urlsafe_b64encode(signature).rstrip(b'=')).decode()


def migrate():
    with psycopg.connect(os.environ['DATABASE_URL'], autocommit=True) as db:
        db.execute('select pg_advisory_lock(674819251)')
        db.execute('create schema if not exists compose_bootstrap')
        db.execute('revoke all on schema compose_bootstrap from public, anon, authenticated')
        db.execute('''create table if not exists compose_bootstrap.migrations (
            name text primary key, checksum text not null, applied_at timestamptz not null default now())''')
        for path in sorted(Path('/app/migrations').glob('*.sql')):
            content = path.read_text()
            checksum = hashlib.sha256(content.encode()).hexdigest()
            row = db.execute('select checksum from compose_bootstrap.migrations where name=%s', (path.name,)).fetchone()
            if row:
                if row[0] != checksum:
                    raise RuntimeError(f'Applied migration changed: {path.name}. Restore it or intentionally reset local volumes.')
                continue
            with db.transaction():
                db.execute(content, prepare=False)
                db.execute('insert into compose_bootstrap.migrations(name, checksum) values (%s, %s)', (path.name, checksum))
            print(f'Applied {path.name}')
        # Seed once: ordinary restarts must not reset local data or passwords.
        seeded = db.execute("select 1 from compose_bootstrap.migrations where name='local-seed'").fetchone()
        if not seeded:
            with db.transaction():
                db.execute(Path('/app/seed.sql').read_text(), prepare=False)
                db.execute("insert into compose_bootstrap.migrations(name,checksum) values ('local-seed','local-fixture')")
        db.execute("notify pgrst, 'reload schema'")
        db.execute('select pg_advisory_unlock(674819251)')


def provision_admin():
    # Container-only address; no configurable public/hosted authentication target.
    origin = 'http://auth:9999'
    key = local_key('service_role')
    headers = {'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'}
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    email, password = 'local-admin@example.test', 'local-admin-password'
    request = urllib.request.Request(origin + '/admin/users', headers=headers,
        data=json.dumps({'email': email, 'password': password, 'email_confirm': True}).encode())
    try:
        with http.open(request, timeout=15) as response:
            user = json.load(response)
    except urllib.error.HTTPError as error:
        if error.code != 422:
            raise
        with http.open(urllib.request.Request(origin + '/admin/users', headers=headers), timeout=15) as response:
            users = json.load(response)['users']
        user = next(u for u in users if u.get('email') == email)
    with psycopg.connect(os.environ['DATABASE_URL']) as db:
        db.execute('insert into private.admins(user_id) values (%s) on conflict do nothing', (user['id'],))
    # Only the public anon key is shared with the web server/browser.
    path = Path('/runtime/local-config.json')
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps({'SUPABASE_ANON_KEY': local_key('anon')}))
    temporary.chmod(0o644)
    temporary.replace(path)
    Path('/runtime/realtime-health-key').write_text(local_key('anon'))
    print('Local fixtures ready. Web app: http://localhost:7357')


if __name__ == '__main__':
    migrate()
    provision_admin()
