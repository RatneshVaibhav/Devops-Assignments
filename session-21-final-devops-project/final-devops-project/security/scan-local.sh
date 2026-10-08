#!/usr/bin/env bash
# scan-local.sh <backend-image> <frontend-image>
# Run every scanner the pipeline runs and write the same reports to reports/.
set -uo pipefail
cd "$(dirname "$0")/.."
BACKEND="${1:?backend image}"; FRONTEND="${2:?frontend image}"
mkdir -p reports
bandit -r application/backend/app -c security/bandit.yaml -f json -o reports/bandit.json -q --exit-zero
semgrep scan --config p/python --config p/react --config security/semgrep-rules.yml --metrics off --quiet \
  --json -o reports/semgrep.json application/backend/app application/frontend/src
pip-audit -r application/backend/requirements.txt -f json -o reports/pip-audit.json >/dev/null 2>&1
(cd application/frontend && npm audit --omit=dev --json > ../../reports/npm-audit.json)
trivy fs --config security/trivy.yaml --quiet --format json -o reports/trivy-fs.json application
# scan exactly what git would commit (CI sees no git-ignored files such as
# kubernetes/db.env or terraform state, so the local scan must not either)
snapshot="$(mktemp -d)"
git ls-files -z -co --exclude-standard . | tar --null -T - -cf - | tar -xf - -C "$snapshot"
gitleaks dir "$snapshot" --config security/.gitleaks.toml --redact --no-banner --log-level error \
  --report-format json --report-path reports/gitleaks.json --exit-code 0
rm -rf "$snapshot"
trivy image --config security/trivy.yaml --quiet --format json -o reports/trivy-image-backend.json "$BACKEND"
trivy image --config security/trivy.yaml --quiet --format json -o reports/trivy-image-frontend.json "$FRONTEND"
ls -1 reports
