# Track System - Cloud-Native DevOps Final Project

Dockerized multi-container application (React/Nginx frontend + Express
backend + PostgreSQL) provisioned on Amazon EKS using Terraform, deployed
via GitHub Actions, and monitored with Prometheus/Grafana.

This repo is a minimal, working reference implementation covering every
requirement in the assignment guide. **The frontend/backend app is
intentionally minimal** (a small leave-request tracker) — the point of the
project is the DevOps pipeline around it, not the app itself. Swap in your
real Track System source under `frontend/` and `backend/` if you have it;
the Dockerfiles, Helm chart, and CI/CD pipelines will keep working as long
as the app still listens on the same ports and exposes `/health`.

---

## 1. Architecture

```
Client Browser
      │
   Route 53 (DNS)
      │
   ALB (Public Subnets)
      │
   EKS Cluster (Private Subnets)
      │
   ┌──────────────┴──────────────┐
   │         Node Group           │
   │  ┌────────────┐ ┌──────────┐ │        AWS Secrets Manager
   │  │ Frontend   │ │ Backend  │◄├───────► (DB credentials)
   │  │ (Nginx)    │ │ (Node)   │ │
   │  └────────────┘ └────┬─────┘ │
   └───────────────────────┼───────┘
                            │
                    Amazon RDS PostgreSQL
                    (private subnets, SG locked
                     to node group on :5432)
```

Images are built from `frontend/` and `backend/`, pushed to Amazon ECR by
the CI pipeline, and rolled out to EKS via Helm.

## 2. Repository layout

```
track-system/
├── frontend/                 # React (Vite) app + multi-stage Dockerfile + nginx.conf
├── backend/                  # Express API + Dockerfile
├── infrastructure/            # Terraform (modularized)
│   ├── bootstrap/             # one-time: creates the S3 state bucket + DynamoDB lock table
│   ├── modules/
│   │   ├── vpc/                # VPC, public/private subnets, IGW, NAT, route tables
│   │   ├── security-groups/    # EKS control-plane / node / RDS security groups
│   │   ├── ecr/                 # ECR repos + lifecycle policies
│   │   ├── eks/                 # EKS cluster + managed node group + IAM
│   │   ├── rds/                 # RDS PostgreSQL instance
│   │   ├── secrets/             # Secrets Manager secret for DB credentials
│   │   └── route53/             # optional DNS record -> ALB
│   ├── main.tf / variables.tf / outputs.tf / versions.tf
│   └── terraform.tfvars.example
├── helm/track-system/          # Helm chart: Deployments, Services, Ingress (ALB)
├── monitoring/
│   ├── namespace.yaml
│   ├── prometheus-values.yaml   # kube-prometheus-stack values (scrapes backend /metrics)
│   └── grafana_dashboard.json   # importable dashboard: "Track System Application Monitoring"
└── .github/workflows/
    ├── terraform.yml            # Pipeline 1: Terraform lifecycle
    └── deploy.yml                # Pipeline 2: build/push/deploy
```

## 3. Prerequisites

- AWS account with permissions to create VPC/EKS/RDS/ECR/IAM/Secrets Manager/Route 53 resources
- Terraform >= 1.7
- kubectl, Helm >= 3.14
- Docker
- A GitHub repo (private) with these **repository secrets** configured:
  - `AWS_DEPLOY_ROLE_ARN` — an IAM role GitHub Actions assumes via OIDC (preferred over long-lived access keys)
- An existing Route 53 public hosted zone, only if you plan to enable the optional DNS record

## 4. One-time bootstrap: Terraform remote state

Terraform's S3 backend can't create its own bucket, so this is created once, manually, with local state:

```bash
cd infrastructure/bootstrap
terraform init
terraform apply
```

This creates the `track-system-terraform-state` S3 bucket (versioned, encrypted, public access blocked) and the `track-system-terraform-locks` DynamoDB table. Update the bucket/table names in `infrastructure/versions.tf` and `bootstrap/variables.tf` if you want different names — they must match.

## 5. Provisioning the infrastructure

```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars   # edit as needed
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Or just push a change under `infrastructure/**` to a feature branch and open a PR — **Pipeline 1** (`terraform.yml`) runs init/fmt/validate/plan automatically and posts the plan as a downloadable artifact; merging to `master` runs `apply`. A manual `workflow_dispatch` input runs `destroy` when you're done testing.

This provisions: VPC (`10.0.0.0/16`) with 2 public + 2 private subnets across 2 AZs, security groups (RDS locked to the EKS node group SG on 5432 only), ECR repos, the EKS cluster + managed node group, the RDS PostgreSQL instance, and a Secrets Manager secret holding the generated DB credentials.

## 6. Secrets wiring (Kubernetes ⇄ Secrets Manager)

The backend expects a Kubernetes Secret named `db-credentials` (see `helm/track-system/values.yaml` → `dbSecretName`) with keys `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`.

**Production approach:** install the [AWS Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) + the AWS provider, then create a `SecretProviderClass` pointing at the secret ARN from `terraform output secrets_manager_secret_name` (ASCP can also sync it into a native Kubernetes Secret, which is what the backend Deployment consumes via `envFrom.secretRef`).

**Local/dev shortcut:** the chart ships a disabled-by-default stub (`helm/track-system/templates/secret-stub.yaml`) you can enable for quick testing:

```bash
helm upgrade --install track-system ./helm/track-system \
  --set devSecretStub.enabled=true \
  --set devSecretStub.dbHost=<rds-endpoint> \
  --set devSecretStub.dbPassword=<password-from-secrets-manager>
```

Never use the dev stub in a real deployment — wire up the CSI driver instead.

## 7. CI/CD pipelines

**Pipeline 1 — `terraform.yml`**: triggers on changes under `infrastructure/**` on `master` (and PRs targeting it). Stages: init → fmt check → validate → plan (uploaded as artifact) → apply (only after merge to `master`) → manual `destroy` via `workflow_dispatch`.

**Pipeline 2 — `deploy.yml`**: triggers on changes under `frontend/**` or `backend/**` on `master`. Stages: lint/unit test → build both Docker images, tag with the short git commit SHA, push to ECR → `aws eks update-kubeconfig` → `helm upgrade --install` with the new image tags → verify rollout status.

Both pipelines authenticate to AWS via OIDC (`aws-actions/configure-aws-credentials` + `role-to-assume`), so no static AWS access keys need to live in GitHub secrets.

## 8. Deploying the app manually (without CI)

```bash
aws eks update-kubeconfig --name track-system-eks --region us-east-1

helm upgrade --install track-system ./helm/track-system \
  --namespace track-system --create-namespace \
  --set frontend.image.repository=<ecr_frontend_repo_url> \
  --set frontend.image.tag=<tag> \
  --set backend.image.repository=<ecr_backend_repo_url> \
  --set backend.image.tag=<tag>

kubectl -n track-system get pods
```

## 9. DNS wiring (Route 53, optional)

Once the app is deployed, the AWS Load Balancer Controller creates an ALB for the Ingress. Get its DNS name and hosted zone ID:

```bash
kubectl -n track-system get ingress track-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Then in `infrastructure/terraform.tfvars`, set `enable_route53 = true` and fill in `hosted_zone_name`, `record_name`, `alb_dns_name`, and `alb_zone_id` (the ALB's hosted zone ID is a fixed AWS value per region, e.g. `Z35SXDOTRQ7X7K` for `us-east-1` ALBs), then re-run `terraform apply`.

## 10. Monitoring (Prometheus & Grafana)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl apply -f monitoring/namespace.yaml

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f monitoring/prometheus-values.yaml
```

Then import the dashboard:

1. Port-forward or expose Grafana: `kubectl -n monitoring port-forward svc/prometheus-grafana 3000:80`
2. Log in (default user `admin`, password from `prometheus-values.yaml` — change it)
3. Dashboards → New → Import → upload `monitoring/grafana_dashboard.json`
4. Select the Prometheus datasource when prompted, click Import

The dashboard ("Track System Application Monitoring") includes the four required panels:
- **Application Health & Availability** — `up{job="track-system"}`
- **CPU Usage (Backend Pods)** — `sum(rate(container_cpu_usage_seconds_total{container=~".*(backend|frontend).*"}[5m])) by (container)`
- **Memory Consumption (RAM)** — `sum(container_memory_working_set_bytes{container=~".*(backend|frontend).*"}) by (container)`
- **Database Storage (Allocated Capacity)** — `kube_persistentvolumeclaim_resource_requests_storage_bytes{persistentvolumeclaim="dbpvc"}`

> **Note:** the last panel assumes a PersistentVolumeClaim named `dbpvc` exists in-cluster, as specified in the assignment. Since this architecture uses managed RDS (not an in-cluster database), that PVC won't exist unless you create a placeholder PVC for grading purposes, or the grading rubric expects this exact query regardless of data source. If your grader expects live values here, either provision a small dummy `dbpvc` PVC, or swap the query for an RDS-appropriate metric (e.g. via the `prometheus-postgres-exporter` or CloudWatch metrics) and note the substitution in your submission video.

The job label `track-system` is set on the backend's `ServiceMonitor` in `monitoring/prometheus-values.yaml` via relabeling, so it matches the dashboard queries out of the box.

## 11. Submission checklist

- [ ] Push this repo (with your real app code if applicable) to a **private** GitHub repository
- [ ] Confirm both GitHub Actions pipelines run green end-to-end
- [ ] Confirm pods are `Running` in the `track-system` namespace on EKS
- [ ] Confirm the Grafana dashboard is live and populated
- [ ] Record the 3-minute submission video showing all of the above
#   T r a c k - S y s t e m - D e v O p s - p r o j e c t  
 