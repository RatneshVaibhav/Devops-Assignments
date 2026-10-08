#!/usr/bin/env bash
# Introduce one finding for each scanner into the WORKING TREE (never committed):
#   SAST     -> app/insecure_admin.py (shell=True, yaml.load, md5, debug=True)
#   SCA      -> vulnerable PyYAML / requests pins in requirements.txt
#   Secrets  -> a campus portal token written into app/settings_local.py
# Undo with: git checkout -- requirements.txt && rm -f app/insecure_admin.py app/settings_local.py
set -euo pipefail
cd "$(dirname "$0")/../.."
cp security/demo/insecure_admin.py app/insecure_admin.py
grep -v '^#' security/demo/vulnerable-requirements.txt >> requirements.txt
# random value, generated at demo time, so no real-looking secret is ever committed
printf 'CAMPUS_PORTAL_TOKEN = "cmp_live_%s"\n' "$(openssl rand -hex 16)" > app/settings_local.py
echo "injected: app/insecure_admin.py, app/settings_local.py, vulnerable pins in requirements.txt"
