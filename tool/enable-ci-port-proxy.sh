#!/usr/bin/env bash
# Isolated GitHub Linux runner only. Internal networks need Docker's port proxy
# for localhost clients; packet forwarding remains blocked by --internal.
set -euo pipefail
sudo python3 - <<'PY'
import json
from pathlib import Path
p = Path('/etc/docker/daemon.json')
config = json.loads(p.read_text()) if p.exists() else {}
config['userland-proxy'] = True
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(json.dumps(config))
PY
sudo systemctl restart docker
