# ADR 0004: psycopg2 Layer ARN via SSM Parameter Store

## Status
Accepted

## Context
The self-built psycopg2 layer (ADR 0003) produces an ARN that is specific
to this AWS account, region, and layer version
(`arn:aws:lambda:us-east-1:221717898536:layer:ha-rds-psycopg2-py312:1`).

Two options were considered for supplying this value to the db-bootstrap
Lambda module:

1. Hardcode it as a `default` in the module's `variables.tf`.
2. Store it in SSM Parameter Store and read it via a Terraform data source.

The ARN itself is not a secret, but it is account- and environment-specific,
and — unlike most configuration values in this project — it took a
multi-hour investigation across three failed approaches (ADR 0003) to
arrive at. That cost is worth preserving outside the Terraform code itself,
so a future rebuild of this project (a new AWS account, a forked copy of
the repo, or this same project revisited months later) does not require
re-discovering it or re-reading git/chat history to recover the right value.

## Decision
Store the layer ARN in SSM Parameter Store at `/ha-rds/psycopg2-layer-arn`
and read it in the `db-bootstrap` module via:

```hcl
data "aws_ssm_parameter" "psycopg2_layer_arn" {
  name = "/ha-rds/psycopg2-layer-arn"
}
```

referenced in the Lambda resource as
`data.aws_ssm_parameter.psycopg2_layer_arn.value`, rather than as a module
input variable with a hardcoded default.

## Consequences
- Both the GitHub Actions plan-only IAM role and the deploy-role policy
  require `ssm:GetParameter`/`ssm:GetParameters` scoped to
  `arn:aws:ssm:us-east-1:221717898536:parameter/ha-rds/*`, added
  specifically to support this data source.
- The value can be updated (e.g., a new layer version published) without
  editing or re-planning any `.tf` file — only the SSM parameter changes.
- This is a deliberately narrower use of SSM than a general configuration-
  management pattern: a plain module variable would have been sufficient
  for a value that changes rarely, but the cost of *rediscovering* this
  specific value if lost was judged high enough to justify decoupling it
  from the Terraform source entirely.

## Alternatives Considered
- **Hardcoded module variable default.** Rejected: ties an account-specific,
  hard-won value directly into version-controlled source, with no path to
  update it without a Terraform change, and no protection against the value
  being lost if this exact module file were ever rewritten.
- **`.tfvars`-injected variable (no SSM).** A reasonable middle ground for
  values that are merely environment-specific but cheap to reproduce.
  Rejected here specifically because this value was expensive to obtain
  (see ADR 0003) — the extra durability of Parameter Store was judged worth
  the small added complexity.