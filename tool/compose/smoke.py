"""Smoke checks for the actual Compose API and persistent installation session."""
import argparse
import json
from pathlib import Path
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--verify-persistence', action='store_true')
args = parser.parse_args()
origin = 'http://127.0.0.1:54321'
http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
with http.open(origin + '/local-config.json', timeout=10) as response:
    public = json.load(response)
assert set(public) == {'SUPABASE_ANON_KEY'}, 'Runtime config must contain only the public key'
key = public['SUPABASE_ANON_KEY']
claims = json.loads(__import__('base64').urlsafe_b64decode(key.split('.')[1] + '==='))
assert claims['role'] == 'anon', 'Privileged key must never reach the web runtime'
Path('.local').mkdir(exist_ok=True)
Path('.local/compose-config.json').write_text(json.dumps({'SUPABASE_URL': origin, 'SUPABASE_ANON_KEY': key}))


def call(path, body=None, token=None):
    headers = {'apikey': key, 'Authorization': 'Bearer ' + (token or key)}
    if body is not None:
        headers['Content-Type'] = 'application/json'
    request = urllib.request.Request(origin + path, headers=headers,
        data=json.dumps(body).encode() if body is not None else None)
    with http.open(request, timeout=15) as response:
        return json.load(response)


proof = Path('.local/compose-persistence.json')
if args.verify_persistence:
    saved = json.loads(proof.read_text())
    session = call('/auth/v1/token?grant_type=refresh_token', {'refresh_token': saved['refresh_token']})
    rows = call('/rest/v1/installations?id=eq.' + saved['id'], token=session['access_token'])
    assert len(rows) == 1 and rows[0]['id'] == saved['id']
    assert rows[0]['receiving'] is False, 'Restart changed saved receiving preference'
    assert rows[0]['display_name'] == 'Compose persistence probe'
    print('Existing installation session, identity and receiving preference survived Compose down/up.')
else:
    session = call('/auth/v1/signup', {})
    member = call('/rest/v1/rpc/join_installation', {
        'p_password': 'local-group-password', 'p_display_name': 'Compose persistence probe',
        'p_device_name': 'Synthetic Compose device', 'p_platform': 'web', 'p_app_version': 'test+1',
        'p_receiving': False}, token=session['access_token'])['installation']
    proof.write_text(json.dumps({'id': member['id'], 'refresh_token': session['refresh_token']}))
    proof.chmod(0o600)
    print('Compose public configuration, anonymous Auth, migrations and local group seed work.')
