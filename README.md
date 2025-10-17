# Chaos Canary — DevOps Showcase

This repository is a DevOps showcase: a small Python/Flask microservice with a reproducible CI/CD pipeline, observability, and a canary + chaos engineering demo.

What you'll find here
- `app/` — Flask app with health and metrics endpoints and configurable failure modes
- `docker/` — Dockerfile and `docker-compose.yml` for local runs
- `k8s/` — Kubernetes manifests (Kustomize-ready) including a canary rollout example
- `terraform/` — Terraform skeleton to provision an AWS EKS cluster (parameterized)
- `.github/workflows/ci.yml` — GitHub Actions workflow to build/test/image
- `prometheus/` — Prometheus config and alert rules
- `tests/` — Basic unit tests

Grafana and demo capture

Grafana is included in the Docker Compose and K8s manifests. It is pre-provisioned with a dashboard located in `grafana/dashboards/chaoscanary-dashboard.json` which shows request rate, error rate and p95 latency.

To run Grafana locally with Compose (included in the compose file):

```powershell
cd .
docker-compose up --build
# then open http://localhost:3000 (admin/admin)
```

To capture a screenshot of the dashboard (requires Node.js and Puppeteer):

```powershell
# install puppeteer locally
npm install puppeteer
npx node ci/capture_dashboard.js http://localhost:3000/d/chaoscanary-overview/chaos-canary-overview grafana-dashboard.png
```

CI artifact

When the GitHub Actions Canary CI runs it deploys Grafana and captures a dashboard screenshot after verification. The screenshot is uploaded as an artifact named `grafana-dashboard` which you can download from the Actions run.

Canary CI

This repo includes a GitHub Actions workflow `.github/workflows/canary-ci.yml` that:
- Builds the application Docker image
- Creates a KinD cluster in the runner
- Deploys a stable deployment and a single-pod canary deployment
- Runs `ci/verify_canary.sh` which toggles failure on the canary and measures the error rate
- If the canary error rate is above the threshold, the script deletes the canary (automatic rollback)

Note: On GitHub Actions the script runs inside the runner where `kubectl` and `kind` are available. The script is provided as-is; make it executable locally with:

```powershell
chmod +x ci/verify_canary.sh
```

Publishing images to GHCR

The Canary CI workflow now publishes the built image to GitHub Container Registry (GHCR). It uses the built-in `${{ secrets.GITHUB_TOKEN }}` and requires that the repository allows `packages: write` for workflows (this is set via the `permissions` field in the workflow). The pushed image name is:

```
ghcr.io/<your-org-or-username>/chaoscanary:<sha>
ghcr.io/<your-org-or-username>/chaoscanary:latest
```

If you prefer to use a different registry (ECR, Docker Hub), I can update the workflow and provide the exact secrets to set.


Quick start (local, Docker Compose)

1. Build and run services:

```powershell
cd docker
docker-compose up --build
```

2. Open the app: http://localhost:5000
3. Prometheus: http://localhost:9090 (if using compose)

Notes
- The Terraform folder contains a starter configuration for AWS EKS — you will need AWS credentials and apply it manually.
- Kubernetes manifests are provided so you can deploy the same app into a cluster and run the canary + chaos experiments.

Resume blurb

Implemented a reproducible canary + chaos engineering demo using Python/Flask, Docker, Kubernetes, Prometheus, and automated CI/CD with GitHub Actions; added Terraform to provision cloud infra (EKS). Demonstrates reliability, observability, GitOps, and automated rollbacks.

Polished resume blurb (short)

Built a canary-based deployment pipeline with automated SLI verification and rollback using Prometheus and GitHub Actions; implemented observability with Prometheus and Grafana, containerized with Docker, and provided Terraform skeleton for EKS provisioning.

Polished resume blurb (detailed)

Implemented a production-like canary pipeline demonstrating modern Site Reliability Engineering practices: containerized a Flask microservice with Docker, instrumented it with Prometheus metrics, built an automated canary verification process in GitHub Actions that queries Prometheus (SLI) and automatically rolls back failing canaries, and integrated Grafana for visual observability. Delivered Terraform skeletons for EKS provisioning, CI workflows for build/publish (GHCR), and README docs and artifacts for reproducible demos.
