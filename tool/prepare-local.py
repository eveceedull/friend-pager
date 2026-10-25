"""Provision only synthetic local fixtures; never accept a remote backend URL."""
import json
import os
from pathlib import Path
import subprocess
import urllib.request
import urllib.error
from urllib.parse import urlparse

status = json.loads(subprocess.check_output(
    ['bash', 'tool/supabase.sh', 'status', '--output', 'json'], text=True))
url = status['API_URL']
assert urlparse(url).hostname in ('127.0.0.1', 'localhost'), 'Local stack required'
email, password = 'local-admin@example.test', 'local-admin-password'
headers = {'apikey': status['SERVICE_ROLE_KEY'],
           'Authorization': 'Bearer ' + status['SERVICE_ROLE_KEY'],
           'Content-Type': 'application/json'}
request = urllib.request.Request(url + '/auth/v1/admin/users', headers=headers,
    data=json.dumps({'email': email, 'password': password, 'email_confirm': True}).encode())
# Explicitly bypass ambient HTTP proxies for loopback requests.
http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
try:
    with http.open(request, timeout=15) as response:
        json.load(response)
except urllib.error.HTTPError as error:
    if error.code != 422:
        raise
    # Verify a previous bootstrap created this exact local user.
    with http.open(urllib.request.Request(url + '/auth/v1/admin/users', headers=headers), timeout=15) as response:
        assert any(u.get('email') == email for u in json.load(response)['users'])
subprocess.run(['docker', 'exec', '-i', 'supabase_db_friend-pager',
    'psql', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'],
    input="insert into private.admins(user_id) select id from auth.users where email = 'local-admin@example.test' on conflict do nothing;", text=True, check=True)
Path('.local').mkdir(exist_ok=True)
config = Path('.local/config.json')
config.write_text(json.dumps({'SUPABASE_URL': url, 'SUPABASE_ANON_KEY': status['ANON_KEY']}, indent=2))
if os.name != 'nt':
    config.chmod(0o600)
print('Local fixtures ready; public connection settings written to .local/config.json')
