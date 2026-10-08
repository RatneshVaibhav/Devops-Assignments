#!/usr/bin/env bash
# inject.sh <fault-file> - merge a fault into environments/dev/values.yaml of the GitOps
# working copy and push it, exactly like a bad pull request being merged.
set -euo pipefail
FAULT="$(realpath "$1")"; REPO="${REPO:-$HOME/shelfshare-gitops}"
python3 - "$REPO/environments/dev/values.yaml" "$FAULT" <<'PY'
import sys, yaml
target, fault = sys.argv[1], sys.argv[2]
text = open(target).read()
header = "".join(l for l in text.splitlines(True) if l.startswith("#"))  # keep the comments on top
doc = yaml.safe_load(text)
def merge(a, b):
    for k, v in b.items():
        if isinstance(v, dict) and isinstance(a.get(k), dict):
            merge(a[k], v)
        else:
            a[k] = v
merge(doc, yaml.safe_load(open(fault)))
class Dumper(yaml.SafeDumper):
    pass
# keep image tags like "1.0.1" or a commit SHA quoted, as CI writes them
Dumper.add_representer(str, lambda d, v: d.represent_scalar(
    "tag:yaml.org,2002:str", v, style='"' if v[:1].isdigit() else None))
with open(target, "w") as fh:
    fh.write(header)
    yaml.dump(doc, fh, Dumper=Dumper, sort_keys=False)
PY
cd "$REPO" && git commit -qam "$(sed -n '1s/^# //p' "$FAULT")" && git push -q && git log --oneline -1
