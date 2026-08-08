This revealed a non-obvious constraint: **RDS Proxy requires a registered
Secrets Manager secret for every distinct database username it proxies for,
even when that username authenticates via IAM auth.** IAM auth changes how
the *client* proves its identity to the Proxy — it does not remove the
Proxy's separate, internal requirement to have a known secret entry mapped
to each username it will accept. A single `auth` block scoped to the master
user's secret does not cover any other role, regardless of how that role
authenticates.

## Decision
1. Generate a random password for `app_user` (`random_password` resource),
   stored in a dedicated Secrets Manager secret
   (`ha-rds/app-user-credentials`), separate from the RDS-managed master
   secret.
2. Add a second `auth` block to the `aws_db_proxy` resource, referencing this
   new secret, alongside the existing master-user block — one `auth` block
   per distinct database user the Proxy serves.
3. Set the actual Postgres role's password to match the secret via
   `ALTER ROLE app_user WITH PASSWORD ...` in the bootstrap Lambda, so the
   Proxy's internal bookkeeping and the role's actual credential stay
   consistent, even though the password itself is never used for real
   client authentication (IAM tokens are used at actual connection time).

## Consequences
- The `app_user` password is functionally a formality required by RDS
  Proxy's architecture, not a real authentication factor — actual client
  authentication still happens via short-lived IAM tokens generated at
  invocation time, consistent with the original no-long-lived-credentials
  design goal.
- The password flows through Terraform state (`sensitive = true` on the
  relevant variables and outputs, but state itself is not exempt from
  containing it) and into the bootstrap Lambda's KMS-encrypted environment
  variables. Both are encrypted at rest via the existing S3 backend
  encryption and Lambda `kms_key_arn` configuration respectively — an
  acceptable tradeoff for this project's scale. A stricter design would
  generate and rotate this password entirely within Secrets Manager,
  without it ever surfacing in Terraform state.
- Every additional database role added to this project in the future (were
  the scope to grow beyond `app_user`) requires its own secret and its own
  `auth` block on the Proxy — this is a structural repeat cost of RDS
  Proxy's design, not something that can be abstracted away in Terraform.

## Alternatives Considered
- **Drop IAM auth entirely, use the app_user's Secrets Manager credential
  directly for authentication.** Rejected — this was the original design's
  explicit goal to avoid (a long-lived credential the Lambda would need to
  handle directly). The per-user secret is required by the Proxy regardless,
  but IAM auth still governs the actual client-to-Proxy handshake.
- **Use only the master user for all application traffic, skip a dedicated
  app_user entirely.** Rejected earlier in the project (see the original
  proxy-module discussion) — using the master role for application writes
  violates least-privilege and was already identified as a shortcut worth
  avoiding.