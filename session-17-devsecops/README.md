# Session 17 — Complete CI/CD & DevSecOps

**Name:** Ratnesh Vaibhav  ·  **Roll No:** 24bcs10413

A CI/CD pipeline with security built into every stage, for a small **Campus Lost & Found API**
(Flask). Students report items they found, search them, and claim them once.

```text
Code → Build → Unit Test → SAST → SCA → Secret Scan → Docker Build → Container Image Scan
     → Security Gate → Push Image → Deploy to Kubernetes
```

| Deliverable | Where |
|---|---|
| Application | [`app/main.py`](app/main.py) (HTTP + security headers), [`app/store.py`](app/store.py) (validation) |
| Unit tests | [`tests/test_api.py`](tests/test_api.py): 9 tests, 97 % coverage |
| Dockerfile | [`Dockerfile`](Dockerfile): `python:3.12-alpine`, non-root uid 10001 |
| GitHub Actions workflow | [`.github/workflows/session-17-devsecops.yml`](../.github/workflows/session-17-devsecops.yml) (repository root, path-filtered to this folder) |
| Security tools configuration | [`security/`](security/): see the table below |
| Kubernetes manifests | [`k8s/`](k8s/): namespace with Pod Security `restricted`, hardened Deployment, Service |
| Pipeline output + screenshots | below; raw logs in [`utility/transcripts/session-17/raw/`](../utility/transcripts/session-17/raw/) |

## Security controls

| Stage | Tool | What it looks for | Config |
|---|---|---|---|
| **SAST** | Bandit 1.9.4 | Python-specific insecure patterns (shell injection, unsafe YAML, weak hashes, hardcoded passwords) | [`security/bandit.yaml`](security/bandit.yaml) |
| **SAST** | Semgrep 1.179 | public `p/python` ruleset + 3 project rules (Flask `debug=True`, `shell=True` with variable input, credentials in string literals) | [`security/semgrep-rules.yml`](security/semgrep-rules.yml) |
| **SCA** | pip-audit 2.10 | known vulnerabilities (PyPA/OSV advisories) in `requirements.txt` and its transitive dependencies | — |
| **SCA** | Trivy fs 0.75 | the same dependency manifest against Trivy's vulnerability DB (HIGH/CRITICAL) | [`security/trivy.yaml`](security/trivy.yaml) |
| **Secret scanning** | Gitleaks 8.30 | 150+ built-in secret patterns + a custom `campus-portal-token` rule; output always `--redact`ed | [`security/.gitleaks.toml`](security/.gitleaks.toml) |
| **Image scanning** | Trivy image 0.75 | OS packages + Python packages inside the built image, **the exact tarball that gets pushed** | [`security/trivy.yaml`](security/trivy.yaml) |
| **Security gate** | [`security-gate.sh`](security/security-gate.sh) | one policy over all six JSON reports: block on any Bandit HIGH, Semgrep ERROR, vulnerable dependency, secret, or HIGH/CRITICAL image CVE; a **missing report also fails** | — |
| **Cluster gate** | Pod Security Admission | the `session17` namespace enforces `restricted`: the API server rejects root, privileged, capability-keeping Pods | [`k8s/namespace.yaml`](k8s/namespace.yaml) |
| Supply chain | [`install-tools.sh`](security/install-tools.sh) | Trivy and Gitleaks are downloaded as **pinned versions and SHA-256 verified** before use, instead of piping an unpinned install script | — |

Design choice: the scanners **report** and the **gate decides**. Each scan job writes JSON and
exits 0; `security-gate` downloads every report and applies the policy in one place. The
policy is versioned in Git, every finding is visible even when several tools fire at once,
and changing a threshold means changing one script.

**Hardened deployment** ([`k8s/deployment.yaml`](k8s/deployment.yaml)): `runAsNonRoot`, uid
10001, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`,
`capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`,
`automountServiceAccountToken: false`, resource limits, readiness/liveness probes, and a
16 Mi `emptyDir` for `/tmp` (gunicorn's only writable path).

---

## 1. The checks, run locally first

![tree of the project, venv, app compiles, 9 tests pass with 97 percent coverage](../utility/screenshots/session-17/01_unit_tests.png)

![Bandit: no issues in 108 lines of code; Semgrep with p/python and project rules: 0 findings in the three app files](../utility/screenshots/session-17/02_sast.png)

![pip-audit: no known vulnerabilities; Trivy fs: requirements.txt 0 vulnerabilities](../utility/screenshots/session-17/03_sca.png)

![Gitleaks over the working tree: no leaks; Gitleaks over the full git history: 5 commits scanned, no leaks](../utility/screenshots/session-17/04_secret_scan.png)

### Choosing the base image with the scanner

![python:3.12-slim has 44 HIGH/CRITICAL CVEs, 43 affected and 1 fix_deferred (no fix available), python:3.12-alpine has 0; the image built on alpine runs as uid 10001 and Trivy finds 0 vulnerabilities in Alpine 3.24.2 and every Python package](../utility/screenshots/session-17/05_image_scan.png)

`python:3.12-slim` (Debian) carries **44 HIGH/CRITICAL CVEs**: 43 `affected` and 1
`fix_deferred`. Debian has not shipped fixes for any of them, so even a rebuild would not
clear them. `python:3.12-alpine` has **0**.
Because of this the gate can block on every HIGH/CRITICAL finding (`ignore-unfixed: false`)
instead of ignoring unfixed ones.

## 2. The security gate: passing, then blocking bad changes

[`security/scan-local.sh`](security/scan-local.sh) runs every scanner exactly as the pipeline
does and writes the same JSON reports.

![security gate with all six checks PASS and SECURITY GATE PASSED, exit code 0](../utility/screenshots/session-17/06_gate_pass.png)

To prove the gate works, [`security/demo/inject-issues.sh`](security/demo/inject-issues.sh)
put one problem for every scanner into the **working tree** (never committed):

- `app/insecure_admin.py` with `shell=True`, `yaml.load`, MD5 for passwords, Flask
  `debug=True` on `0.0.0.0` ([source](security/demo/insecure_admin.py));
- old `PyYAML==5.3.1` and `requests==2.19.1` pins;
- a campus-portal token in `app/settings_local.py`, generated with `openssl rand` at demo
  time so no real-looking secret ever exists in the repository.

![after injecting the issues every check fails: bandit 6 findings 2 blocking, semgrep 8 and 5, pip-audit 39, trivy-fs 2, gitleaks 2, trivy-image 8; SECURITY GATE FAILED, exit code 1](../utility/screenshots/session-17/07_gate_blocks.png)

![finding details: Bandit HIGH B602 shell=True and B324 MD5, Semgrep ERROR rules including flask-debug-enabled and hardcoded-credential-assignment, pip-audit advisories for pyyaml, requests, idna and urllib3, gitleaks campus-portal-token and generic-api-key with the secret REDACTED, Trivy image CVE-2020-14343 PyYAML and CVE-2018-18074 requests](../utility/screenshots/session-17/08_gate_findings_detail.png)

![issues removed, all checks PASS again, gate exit code 0](../utility/screenshots/session-17/09_gate_fixed.png)

What it showed:

- **Defence in depth:** the leaked token was caught by **three** tools: Gitleaks (the custom
  `campus-portal-token` rule *and* the generic rule), Semgrep (project rule) and Bandit (B105,
  LOW). `requests 2.19.1` was caught by both pip-audit and Trivy. One tool missing a finding is
  not fatal.
- **SCA sees transitive dependencies:** pinning `requests` pulled in `urllib3 1.23` and
  `idna 2.7`, which were never listed but account for most of the 39 advisories.
- **Scanner reports leak secrets.** My first run of the "details" screenshot printed Bandit's
  `issue_text` for B105, which contains the token value itself. I deleted that transcript and
  re-recorded with a redaction filter, and the pipeline prints only the rule name, never
  `issue_text`. Scan reports are sensitive artifacts.

## 3. The pipeline (GitHub Actions, executed with act)

Run locally with [act](https://github.com/nektos/act), exactly as in Session 16 (local registry
instead of GHCR, lab cluster through the `KUBE_CONFIG` secret). On GitHub the same file pushes
to `ghcr.io` and deploys into a throw-away kind cluster.

![act exit code 0 and all ten jobs succeeded: build, unit tests, SAST, SCA, secret scan, docker build, image scan, security gate, push, deploy](../utility/screenshots/session-17/10_act_run_success.png)

![every main step of the ten jobs with a green check](../utility/screenshots/session-17/11_act_steps.png)

![key outputs: 9 tests passed 97 percent, semgrep 0 findings, pip-audit 0 vulnerabilities, gitleaks 0, trivy and gitleaks installed with sha256 verified, the gate table with all PASS, image pushed with the commit SHA tag, rollout complete, two pods running, smoke test health ok and a created item](../utility/screenshots/session-17/12_act_key_outputs.png)

Full log: [`raw/act-run-1-success.txt`](../utility/transcripts/session-17/raw/act-run-1-success.txt) (1276 lines).
The image tag `48197fa…` is the commit that was scanned.

### The gate blocking a deployment in CI

The same injected issues, committed nowhere, run through the full pipeline:

![jobs 1 to 7 succeed, 8 Security gate fails; bandit 6 findings 2 HIGH, semgrep 8, gitleaks 2, pip-audit 39; gate table all FAIL; push and deploy have 0 log lines; the registry still holds only the earlier good tag; working tree restored](../utility/screenshots/session-17/13_act_run_gate_blocks.png)

- Every scan job still **succeeded**: they only report. The **gate job failed** and stopped
  the run.
- `9 Push image` and `10 Deploy to Kubernetes` produced **0 log lines**: they never started.
  The registry still holds only the earlier, clean tag.
- Full log: [`raw/act-run-2-gate-blocks.txt`](../utility/transcripts/session-17/raw/act-run-2-gate-blocks.txt).
  It was checked with grep for the injected token value (0 hits).

## 4. What is running in the cluster

![namespace session17 labelled pod-security enforce restricted, two pods, NodePort 30002, image tag is the commit SHA, the container runs as uid 10001, writing to the app directory fails with read-only file system, health and a created item with nosniff and DENY headers, markup in location rejected, and a privileged root pod is forbidden by PodSecurity restricted with six violations](../utility/screenshots/session-17/14_verify_cluster.png)

- `id` → `uid=10001(appuser)`; `touch /srv/app/hacked.py` → `Read-only file system`. Even
  code-execution inside the container cannot modify the app.
- Responses carry `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` and a
  restrictive CSP; `<script>` in input is rejected by validation.
- `kubectl run` of a **privileged root Pod** is refused by the API server with six Pod Security
  violations (privileged, privilege escalation, capabilities, runAsNonRoot, runAsUser=0,
  seccomp). The cluster enforces the same rules as the pipeline.
