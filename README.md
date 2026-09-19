# ha-rds-inventory

A serverless, event-driven, highly-available inventory system on AWS — built as a security-focused infrastructure portfolio project, not a tutorial walkthrough. Every architectural choice is documented as an [ADR](./docs/adr/), and every scanner exception has a stated, defensible reason in [`docs/security/scan-exceptions.md`](./docs/security/scan-exceptions.md).

## What this is

A `POST /orders` API that decrements stock for a SKU, backed by a Multi-AZ Aurora Serverless v2 cluster, with no EC2, no long-lived database credentials, and no public database access anywhere in the design.

```
Client
  │
  ▼
API Gateway (HTTP API)
  │
  ▼
Lambda (write-order, VPC-attached, private subnet)
  │  IAM auth token generated at invocation — no stored app password
  ▼
RDS Proxy (connection pooling, IAM auth required)
  │
  ▼
Aurora Serverless v2 (PostgreSQL, Multi-AZ writer + reader)
```

## Why this project exists

Most "deploy RDS to AWS" portfolio repos are the same AWS tutorial with different resource names. This one exists to demonstrate:

- **Design judgment under real constraints** — every non-obvious decision (why RDS Proxy needs a per-user secret even under IAM auth, why the default security group is explicitly locked down, why a NAT Gateway was rejected in favor of VPC endpoints) is written up as an ADR, not left implicit.
- **A working CI/CD pipeline with least-privilege IAM**, not a green checkmark from an overprivileged role — the plan-only CI role and the apply-only CD role are deliberately separate, and every permission each one holds is scoped to `ha-rds-*` resources wherever AWS allows resource-level scoping.
- **A documented security posture**, including the handful of Checkov findings that were deliberately skipped, each with a stated, revisitable reason — not silently suppressed.

## Architecture decisions (ADRs)

| ADR | Decision |
|---|---|
| [0001](./docs/adr/) | Multi-AZ Aurora Serverless v2, RDS Proxy, VPC endpoints over NAT Gateway |
| [0002](./docs/adr/0002-security-group-hardening.md) | Explicit SG rule descriptions; default VPC security group locked to zero rules |
| [0003](./docs/adr/0003-psycopg2-layer-strategy.md) | Self-built psycopg2 Lambda layer, after two public-layer options were confirmed unavailable for this runtime/region |
| [0004](./docs/adr/0004-layer-arn-ssm-parameter-store.md) | Layer ARN stored in SSM Parameter Store rather than hardcoded, since it was expensive to obtain |
| [0005](./docs/adr/0005-rds-proxy-per-user-secrets.md) | RDS Proxy requires a registered Secrets Manager secret per database user, even when that user authenticates via IAM — a non-obvious constraint discovered during integration testing |

## Modules

| Module | Responsibility |
|---|---|
| `modules/networking` | VPC, private subnets (2 AZs), security groups, VPC interface endpoints (Secrets Manager, CloudWatch Logs), VPC flow logs, KMS |
| `modules/database` | Aurora Serverless v2 cluster (Multi-AZ writer + reader), KMS-encrypted storage and logs, IAM DB auth, Performance Insights, Enhanced Monitoring, query logging |
| `modules/proxy` | RDS Proxy, per-user Secrets Manager entries, IAM-auth-required connection pooling |
| `modules/db-bootstrap` | Two Lambdas: schema migration (creates `inventory`/`orders` tables) and role bootstrap (creates the least-privilege `app_user` Postgres role, grants `rds_iam`) |
| `modules/write-lambda` | API Gateway HTTP API → VPC-attached write Lambda, connecting through the Proxy via short-lived IAM auth tokens (no stored application password) |

## Security highlights

- **No stored application database password.** The write Lambda generates a short-lived IAM auth token on every invocation (`rds_client.generate_db_auth_token()`) rather than holding a credential in its environment.
- **Nothing reaches the database except the Proxy.** Security groups are chained Lambda → Proxy → DB, each hop explicit, each rule described in-console (not just in code).
- **No NAT Gateway.** All AWS-service traffic (Secrets Manager, CloudWatch Logs) from the private-subnet Lambdas goes through VPC interface endpoints instead, keeping the design's "no public egress" property intact rather than quietly reintroducing internet access for convenience.
- **Every KMS key has an explicit policy** — no implicit default key policies anywhere in the stack.
- **CI and CD use separate, narrowly-scoped IAM roles** authenticated via GitHub OIDC — no long-lived AWS keys in GitHub, and the CI role literally cannot create or modify infrastructure (read-only actions only).

## CI/CD

- **CI** (`ha-rds-terraform-ci.yml`): on every PR, runs `terraform fmt`, `validate`, Checkov, Trivy, and `terraform plan`, using a plan-only IAM role.
- **CD** (`ha-rds-terraform-cd.yml`): on push to `main` (paths under `environments/dev/**` or `modules/**`), runs `terraform apply` using a separate, scoped deploy role.
- Every deliberate Checkov skip is logged in [`docs/security/scan-exceptions.md`](./docs/security/scan-exceptions.md) with a reason and a revisit condition — nothing is suppressed silently.

## Known limitations / honest gaps

- **`POST /orders` is unauthenticated** (`authorization_type = "NONE"`) — a deliberate tradeoff to keep the failover load-test script simple (plain HTTP requests, no SigV4 signing). A production version would use IAM or JWT authorization on this route.
- **CI catches issues after push, not before** — there's no local pre-commit hook running `terraform fmt`/`tflint`/Checkov yet, so the feedback loop is currently push → wait for CI → fix, rather than catching mechanical issues before they leave the laptop.
- **No AWS Backup plan** — native RDS automated backups are enabled (7-day retention), but there's no unified backup policy across services, since this project only has one data store.
- **Deletion protection is off and `skip_final_snapshot` is true** — a deliberate choice so the whole stack can be torn down and rebuilt cheaply between working sessions; not a production posture.

## Local development

```bash
cd environments/dev
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply "tfplan"
```

Requires an AWS profile with permissions matching the scoped policies this project uses (see `docs/adr/` for the reasoning behind each permission set) and the following pre-existing out-of-band resources:
- An SSM parameter at `/ha-rds/psycopg2-layer-arn` pointing to a self-built psycopg2 Lambda layer (see ADR 0003) — Terraform reads this via a data source, it does not create the layer itself.

## Repo structure

```
environments/dev/       — root Terraform config, backend, provider setup
modules/
  networking/
  database/
  proxy/
  db-bootstrap/
  write-lambda/
docs/
  adr/                   — architecture decision records
  security/
    scan-exceptions.md   — every deliberate Checkov/Trivy skip, with reasoning
.github/workflows/
  ha-rds-terraform-ci.yml
  ha-rds-terraform-cd.yml
```

