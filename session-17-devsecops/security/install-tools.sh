#!/usr/bin/env bash
# Install pinned scanner versions and verify them against the published SHA-256
# checksums before use - a tampered download stops the pipeline here.
set -euo pipefail
TRIVY_VERSION=0.75.0
TRIVY_SHA256=c6e65abddb348e25f10549df887045629cf28cc72453cd1c63acb717316b3f3f
GITLEAKS_VERSION=8.30.1
GITLEAKS_SHA256=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
BIN="${1:-/usr/local/bin}"
mkdir -p "$BIN"; export PATH="$BIN:$PATH"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

fetch() {  # fetch <url> <sha256> <binary>
  curl -sSL -o "$tmp/pkg.tgz" "$1"
  echo "$2  $tmp/pkg.tgz" | sha256sum -c --quiet -
  tar -xzf "$tmp/pkg.tgz" -C "$tmp" "$3"
  install -m 0755 "$tmp/$3" "$BIN/$3"
  rm -f "$tmp/pkg.tgz"
  echo "installed $3 (sha256 verified)"
}
need() { command -v "$1" >/dev/null 2>&1 && "$1" --version 2>/dev/null | grep -q "$2"; }

need trivy "$TRIVY_VERSION" || fetch \
  "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
  "$TRIVY_SHA256" trivy
need gitleaks "$GITLEAKS_VERSION" || fetch \
  "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  "$GITLEAKS_SHA256" gitleaks
trivy --version | head -1
echo "gitleaks $(gitleaks version)"
