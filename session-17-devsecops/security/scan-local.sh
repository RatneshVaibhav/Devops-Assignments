#!/usr/bin/env bash
# scan-local.sh <image> - run every scanner the pipeline runs, writing the same
# JSON reports to reports/, so security-gate.sh can be tried before pushing.
set -uo pipefail
cd "$(dirname "$0")/.."
IMAGE="${1:-session17-lost-and-found:local}"
mkdir -p reports
bandit -r app -c security/bandit.yaml -f json -o reports/bandit.json -q --exit-zero
semgrep scan --config p/python --config security/semgrep-rules.yml --metrics off --quiet --json -o reports/semgrep.json app
pip-audit -r requirements.txt -f json -o reports/pip-audit.json >/dev/null 2>&1
trivy fs --config security/trivy.yaml --quiet --format json -o reports/trivy-fs.json .
gitleaks dir . --config security/.gitleaks.toml --redact --no-banner --log-level error \
  --report-format json --report-path reports/gitleaks.json --exit-code 0
trivy image --config security/trivy.yaml --quiet --format json -o reports/trivy-image.json "$IMAGE"
ls -1 reports
