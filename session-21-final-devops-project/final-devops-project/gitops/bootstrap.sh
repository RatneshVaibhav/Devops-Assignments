#!/usr/bin/env bash
# bootstrap.sh - publish the chart and the environment values to the GitOps repository
# (Gitea inside the cluster) and register the Argo CD Application.
# Needs GITEA_PW (admin password) and GIT_CREDS (git credential-store file) in the environment.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
GITEA=http://gitea.localhost:8088
REPO=shelfshare-gitops
WORK="${WORK:-$HOME/$REPO}"

curl -sf -u "ratnesh:$GITEA_PW" -X POST "$GITEA/api/v1/user/repos" -H "Content-Type: application/json" \
  -d "{\"name\":\"$REPO\",\"description\":\"ShelfShare desired state (Helm chart + environments)\",\"private\":false}" \
  | jq -r '"created " + .full_name' || echo "repository already exists"

rm -rf "$WORK" && git clone -q "$GITEA/ratnesh/$REPO.git" "$WORK" 2>/dev/null
cd "$WORK"
git config user.name "Ratnesh Vaibhav"
git config user.email 180539626+RatneshVaibhav@users.noreply.github.com
git config credential.helper "store --file=$GIT_CREDS"
git checkout -q -B main
mkdir -p charts environments
cp -r "$PROJECT/helm/shelfshare" charts/
cp -r "$PROJECT/gitops/environments/." environments/
printf '# shelfshare-gitops\n\nDesired state of ShelfShare. Argo CD watches this repository.\n\n- `charts/shelfshare` - the Helm chart\n- `environments/<env>/values.yaml` - per-environment values; CI bumps `image.tag`\n' > README.md
git add . && git commit -q -m "Bootstrap: shelfshare chart 1.0.0 and dev environment" && git push -q -u origin main
git log --oneline -1
kubectl apply -f "$HERE/argocd/shelfshare-app.yaml"
