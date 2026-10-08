#!/usr/bin/env bash
# security-gate.sh <reports-dir>
# One policy over every scanner report. Blocks on:
#   SAST     any Bandit HIGH, any Semgrep ERROR
#   SCA      any known-vulnerable Python dependency (pip-audit),
#            any HIGH/CRITICAL npm advisory in runtime dependencies, any HIGH/CRITICAL in Trivy fs
#   SECRETS  any Gitleaks finding
#   IMAGES   any HIGH/CRITICAL CVE in the backend or frontend image
# A missing report fails too: a scan that did not run is not a pass.
set -uo pipefail
R="${1:-reports}"
blocked=0
printf '\n%-8s %-22s %9s %9s  %s\n' CHECK TOOL FINDINGS BLOCKING RESULT
printf '%-8s %-22s %9s %9s  %s\n' ------ -------------------- -------- -------- ------

row() {  # row <check> <tool> <file> <jq-total> <jq-blocking>
  local total block result
  if [ ! -s "$R/$3" ]; then
    total="-"; block="-"; result="FAIL (report missing)"; blocked=1
  else
    total=$(jq -r "$4" "$R/$3"); block=$(jq -r "$5" "$R/$3")
    if [ "$block" -gt 0 ]; then result="FAIL"; blocked=1; else result="PASS"; fi
  fi
  printf '%-8s %-22s %9s %9s  %s\n' "$1" "$2" "$total" "$block" "$result"
}
HC='[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH" or .Severity == "CRITICAL")] | length'
ALL='[.Results[]?.Vulnerabilities[]?] | length'

row SAST    "bandit (backend)"      bandit.json  '.results | length' '[.results[] | select(.issue_severity == "HIGH")] | length'
row SAST    "semgrep (both)"        semgrep.json '.results | length' '[.results[] | select(.extra.severity == "ERROR")] | length'
row SCA     "pip-audit (backend)"   pip-audit.json '[.dependencies[].vulns[]] | length' '[.dependencies[].vulns[]] | length'
row SCA     "npm audit (frontend)"  npm-audit.json '.metadata.vulnerabilities.total' '.metadata.vulnerabilities.high + .metadata.vulnerabilities.critical'
row SCA     "trivy fs"              trivy-fs.json "$ALL" "$HC"
row SECRETS "gitleaks"              gitleaks.json 'length' 'length'
row IMAGE   "trivy backend image"   trivy-image-backend.json "$ALL" "$HC"
row IMAGE   "trivy frontend image"  trivy-image-frontend.json "$ALL" "$HC"
echo
if [ "$blocked" -ne 0 ]; then
  echo "SECURITY GATE: FAILED - images will not be pushed, nothing will be deployed"
  exit 1
fi
echo "SECURITY GATE: PASSED - images may be pushed and deployed"
