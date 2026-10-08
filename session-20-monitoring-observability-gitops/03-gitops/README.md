# 03 — GitOps demo with Argo CD

The concepts (GitOps principles, Git as source of truth, declarative configuration,
continuous reconciliation, workflow, Argo CD vs Flux) are written up in
[`CONCEPTS.md`](CONCEPTS.md). This page is the hands-on part: every claim there, shown on a
real cluster.

```text
 developer (laptop)                       kind cluster
 ~/campus-gitops ──git push──► Gitea  ◄──poll every 30 s── Argo CD ──apply / prune / self-heal──► namespace campus-gitops
  (working clone)              (Git server,                (application-controller,               notice-board Deployment,
                                ratnesh/campus-gitops)      repo-server, server)                   Service, ConfigMaps
```

**Why Gitea?** A GitOps agent needs a Git remote to watch. Gitea, a self-hosted Git server
deployed *inside* the cluster ([`gitea/gitea.yaml`](gitea/gitea.yaml)), plays the role of
GitHub, so the whole loop runs on the laptop and nothing is pushed to my real GitHub account.
To use GitHub instead, put the `app/` folder in a GitHub repository and change `repoURL` in
[`argocd/campus-gitops-app.yaml`](argocd/campus-gitops-app.yaml).

| File | Purpose |
|---|---|
| [`gitea/gitea.yaml`](gitea/gitea.yaml) | Gitea 28.1 (rootless, SQLite on a PVC), Service, Ingress `gitea.localhost` |
| [`argocd/values.yaml`](argocd/values.yaml) | argo/argo-cd 10.10.0 (Argo CD v3.5.4): Dex/notifications/ApplicationSet off, `timeout.reconciliation: 30s`, read-only anonymous UI, Ingress `argocd.localhost` |
| [`argocd/campus-gitops-app.yaml`](argocd/campus-gitops-app.yaml) | the `Application`: repo + path `app`, destination namespace, `automated: {prune, selfHeal}`, `CreateNamespace=true` |
| [`gitops-repo/`](gitops-repo/) | the GitOps repository's final content (identical to Gitea at `cc9fc8d`) |
| [`campus-gitops.bundle`](campus-gitops.bundle) | the repository **with its full history**: `git clone campus-gitops.bundle` |

---

## 1. Install Gitea and Argo CD

![gitea applied and rolled out, gitea API version 28.1.0, helm install of argo-cd 10.10.0, gitea pod and the argocd application-controller, redis, repo-server and server pods running, ingresses for gitea.localhost and argocd.localhost, argocd CLI v3.5.4](../../utility/screenshots/session-20/11_install_gitea_argocd.png)

## 2. Create the Git repository and push the desired state

![gitea admin user created, repo ratnesh/campus-gitops created through the API, cloned to ~/campus-gitops, the app folder with configmap, deployment, exam-banner and service, first commit pushed](../../utility/screenshots/session-20/12_gitops_repo.png)

The Gitea password is random, kept in a private file, and appears only as `$GITEA_PW` /
`$GIT_CREDS` in the transcripts.

## 3. Register the Application (the only manual `kubectl apply`)

![the Application manifest, application campus-gitops Synced and Healthy, argocd app get showing source repo, Automated (Prune), Synced to main (8d6311e), every resource Synced and Healthy, the commit in git is 8d6311e, deployment 2/2, page served says Release 1](../../utility/screenshots/session-20/13_argocd_sync_1.png)
![the notice board page served by the pods: Release 1 deployed by Argo CD from Git](../../utility/screenshots/session-20/13_argocd_sync_2.png)

Argo CD created the namespace (`CreateNamespace=true`) and every object in `app/`. The synced
revision is exactly the commit at the head of `main`.

## 4. Change Git → the cluster follows

![diff replicas 2 to 3 and Release 2 text, commit pushed at 14:41:40, cluster converged at 14:42:23, Synced to main (ff4a5de), 3 of 3 pods, the page still showed release 1, the configmap already had release 2, the file inside the pod updated at 14:43:23, history with two revisions](../../utility/screenshots/session-20/14_git_change.png)

- Push at **14:41:40**, three replicas ready at **14:42:23**: 43 s, within the 30 s
  reconciliation interval plus rollout time. No `kubectl` was used.
- The new page text took another minute to appear. Argo CD updated the ConfigMap immediately,
  but the kubelet refreshes ConfigMap **volumes** on its own sync period (about 1 min), and
  the Pods were not restarted. For instant config changes, add a checksum annotation to the
  Pod template (as in the Session 15 notes chart) so a config change rolls the Pods.

## 5. Self-healing

![kubectl scale to 1 replica: desired is already back to 3 when the command returns, 10 s later 3/3, events scaled down 3 to 1 and two seconds later up to 3, the last sync was automated, still Synced to ff4a5de](../../utility/screenshots/session-20/15_self_heal.png)

Someone ran `kubectl scale --replicas=1`. Before the command even returned, Argo CD had
already put **desired = 3** back (the events show the scale-down and the scale-up two
seconds apart; the last sync is `automated=true`). The cluster cannot drift from Git.

## 6. Pruning and rollback by `git revert`

![the exam-week-banner configmap exists, git rm and push at 14:46:11, the configmap is gone at 14:46:27, git log, git revert of the release 2 commit pushed at 14:46:30, back to 2 replicas at 14:47:04, argocd app history with four revisions, Synced to main cc9fc8d](../../utility/screenshots/session-20/16_prune_and_revert.png)

- **Prune:** deleting `exam-banner.yaml` from Git removed the ConfigMap from the cluster
  16 s later (`prune: true`). Without prune it would linger as an orphan.
- **Rollback = `git revert`:** reverting the "release 2" commit took the cluster back to 2
  replicas and the release 1 page, as a new, reviewable commit. Nobody needed cluster access.

## 7. The UI and the Git history

![Argo CD UI: app health Healthy, sync status Synced to main cc9fc8d, auto sync enabled, last sync OK by Ratnesh Vaibhav for the revert commit, resource tree with the configmap, service, deployment, replica set and pods](../../utility/screenshots/session-20/web_07_argocd_app_tree.png)

![Gitea commit list of ratnesh/campus-gitops: the four commits from initial deploy to revert](../../utility/screenshots/session-20/web_08_gitea_commits.png)

![gitops-repo snapshot extracted from HEAD is identical to the Gitea repository at cc9fc8d, bundle created and verified, cloning the bundle shows the four commits](../../utility/screenshots/session-20/17_gitops_repo_snapshot.png)

## Things I learned the hard way

- In Argo CD 3.x the per-resource health is no longer stored in `.status.resources[].health`
  (it is served from the resource tree), so `kubectl get application -o jsonpath` shows it
  empty. `argocd app get` shows it properly.
- `argocd --core` reads the namespace from the current kube context. Here the CLI talks to the
  API server through the ingress instead
  (`ARGOCD_OPTS="--server argocd.localhost:8088 --plaintext --grpc-web"`) with read-only
  anonymous access.
- The Argo CD UI keeps a server-sent-events stream open, which never lets headless Chrome's
  `--virtual-time-budget` finish. [`webshot.py`](../../utility/tools/webshot.py) gained a mode
  that drives Chrome over the DevTools protocol and captures once the page shows given text.
