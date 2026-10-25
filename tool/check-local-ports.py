"""Ensure disposable backend ports are not published on public/LAN interfaces."""
import json
import subprocess

network = json.loads(subprocess.check_output(
    ['docker', 'network', 'inspect', 'friend-pager-local'], text=True))[0]
assert network['Options']['com.docker.network.bridge.host_binding_ipv4'] == '127.0.0.1'
assert network['Containers'], 'No stack containers to inspect'
for container in network['Containers']:
    ports = json.loads(subprocess.check_output(['docker', 'inspect', '--format',
        '{{json .NetworkSettings.Ports}}', container], text=True)) or {}
    for bindings in ports.values():
        for binding in bindings or []:
            assert binding['HostIp'] in ('127.0.0.1', '::1'), 'Non-loopback port publication'
print('All backend published ports are bound to loopback.')
