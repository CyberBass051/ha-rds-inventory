# ADR 0002: Security Group Hardening — Explicit Descriptions and Locked-Down Default SG

## Status
Accepted

## Context
Checkov flagged two findings during CI on the networking module:

- `CKV_AWS_23`: the four security group rules connecting Lambda → RDS Proxy → Aurora
  had no `description` field set.
- `CKV2_AWS_12`: the VPC's default security group — created automatically by AWS,
  not managed explicitly in this codebase — was left in its default state, which
  allows all traffic between any resources placed into it.

Neither finding blocks functionality. Both represent gaps between the project's
stated design intent (nothing reaches the Aurora cluster except through RDS Proxy;
nothing reaches the Proxy except the write Lambda) and what was actually enforced
in code.

## Decision
1. **Add explicit descriptions to every security group rule.** Each rule's
   `description` states which side of the Lambda → Proxy → DB chain it permits,
   so the intent is visible directly in the AWS console and in `terraform plan`
   output, not only in this ADR.

2. **Explicitly manage the VPC's default security group and strip all rules from
   it**, using `aws_default_security_group` with empty `ingress`/`egress` blocks.
   AWS creates this security group automatically and allows all traffic within it
   by default; leaving it unmanaged means an unused-but-open group with an
   allow-all rule set sits in the VPC alongside every other group that was
   deliberately locked down. Managing it explicitly and clearing it forces any
   resource placed in the VPC to be assigned one of the purpose-built groups
   (`lambda`, `proxy`, `db`, `vpc_endpoints`) rather than silently inheriting
   default-allow-all behavior.

## Consequences
- No functional change: nothing in this project currently uses the default SG,
  so clearing it doesn't affect the write Lambda, Proxy, or Aurora cluster.
- Any future resource added to this VPC that isn't explicitly assigned a security
  group will have zero effective network access, by design — this is intended
  friction. A developer adding a new resource is forced to make an explicit SG
  decision rather than falling back on a permissive default.
- Rule descriptions add a small amount of boilerplate per `aws_security_group_rule`
  block but cost nothing in terms of runtime behavior.

## Alternatives Considered
- **Leave the default SG unmanaged, suppress `CKV2_AWS_12` with a documented
  skip.** Rejected — this is exactly the kind of default-permissive AWS behavior
  the project's whole design is meant to avoid; skipping the check would be
  papering over a real gap rather than closing it, and undermines the
  "security-hardened, not just functional" premise of the project.