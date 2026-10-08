#!/usr/bin/env bash
# security-gate.sh <reports-dir>
# Reads the JSON reports of every scanner and applies one policy:
#   block on  - any Bandit HIGH or Semgrep ERROR finding (SAST)
#             - any dependency with a known vulnerability (pip-audit / Trivy fs)
#             - any detected secret (Gitleaks)
#             - any HIGH/CRITICAL CVE in the container image (Trivy image)
# A missing report is itself a failure: a scan that did not run is not a pass.
set -uo pipefail
R="${1:-reports}"
blocked=0
printf '\n%-9s %-12s %9s %9s  %s\n' CHECK TOOL FINDINGS BLOCKING RESULT
printf '%-9s %-12s %9s %9s  %s\n' ------- ---------- -------- -------- ------

row() {  # row <check> <tool> <file> <jq-total> <jq-blocking>
  local total block result
  if [ ! -s "$R/$3" ]; then
    total="-"; block="-"; result="FAIL (report missing)"; blocked=1
  else
    total=$(jq -r "$4" "$R/$3"); block=$(jq -r "$5" "$R/$3")
    if [ "$block" -gt 0 ]; then result="FAIL"; blocked=1; else result="PASS"; fi
  fi
  printf '%-9s %-12s %9s %9s  %s\n' "$1" "$2" "$total" "$block" "$result"
}

row SAST    bandit      bandit.json      '.results | length' \
                                         '[.results[] | select(.issue_severity == "HIGH")] | length'
row SAST    semgrep     semgrep.json     '.results | length' \
                                         '[.results[] | select(.extra.severity == "ERROR")] | length'
row SCA     pip-audit   pip-audit.json   '[.dependencies[].vulns[]] | length' \
                                         '[.dependencies[].vulns[]] | length'
row SCA     trivy-fs    trivy-fs.json    '[.Results[]?.Vulnerabilities[]?] | length' \
                                         '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH" or .Severity == "CRITICAL")] | length'
row SECRETS gitleaks    gitleaks.json    'length' 'length'
row IMAGE   trivy-image trivy-image.json '[.Results[]?.Vulnerabilities[]?] | length' \
                                         '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH" or .Severity == "CRITICAL")] | length'
echo
if [ "$blocked" -ne 0 ]; then
  echo "SECURITY GATE: FAILED - the image will not be pushed or deployed"
  exit 1
fi
echo "SECURITY GATE: PASSED - image may be pushed and deployed"
