# Session 20 — Monitoring, Observability & GitOps

**Name:** Ratnesh Vaibhav  ·  **Roll No:** 24bcs10413

| Task | Folder | Content |
|---|---|---|
| 1 — Monitoring | [`01-monitoring/`](01-monitoring/) | kube-prometheus-stack + an instrumented app: metrics, JSON logs, 5 alerts fired on purpose and routed to a webhook receiver, CPU, memory, application health, Grafana dashboard |
| 2 — Observability | [`02-observability/README.md`](02-observability/README.md) | the three pillars (metrics, logs, traces), why observability is needed (SLIs/SLOs, error budgets), common tools, Kubernetes observability |
| 3 — GitOps | [`03-gitops/`](03-gitops/) ([concepts](03-gitops/CONCEPTS.md)) | Argo CD watching an in-cluster Git server: sync, change via Git, self-heal, prune, rollback by `git revert` |

Everything ran on my laptop's kind cluster (`devops-lab`, Kubernetes v1.37.0). Terminal
screenshots are rendered from the transcripts in
[`utility/transcripts/session-20/`](../utility/transcripts/session-20/); browser screenshots
(`web_*.png`) are headless-Chrome captures of the real UIs, with the URL shown in the frame.

## Deliverables checklist

| Deliverable | Where |
|---|---|
| Monitoring demo | [`01-monitoring/README.md`](01-monitoring/README.md) |
| Observability documentation | [`02-observability/README.md`](02-observability/README.md) |
| GitOps demo | [`03-gitops/README.md`](03-gitops/README.md) |
| Screenshots | [`utility/screenshots/session-20/`](../utility/screenshots/session-20/) |
| README.md | this file + one per task |

## Highlights

- **Alert lifecycle observed end to end:** `inactive → pending → firing` in Prometheus, routed
  by label (`team=campus-web`) in Alertmanager, delivered to a webhook, then `RESOLVED`, for
  error rate, p95 latency, CPU per pod, and a critical "no replicas" outage.
- **The CPU alert did not fire at 74 % of the limit** (threshold 80 %) and did at 83–88 %.
  The rule really evaluates the data; it isn't hard-wired to the demo.
- **GitOps loop timed:** push → 3 replicas in 43 s; manual `kubectl scale` undone in about 2 s;
  a file deleted from Git pruned in 16 s; `git revert` rolled the cluster back.
- Real problems hit and fixed along the way: Grafana `OOMKilled` at 256Mi, the default `null`
  Alertmanager receiver, `kubectl logs -l` keeping only 10 lines per pod, `group_wait`
  swallowing a short outage, a duplicate-series `or vector(0)`, Argo CD 3 health fields, and
  headless capture of a streaming UI.
