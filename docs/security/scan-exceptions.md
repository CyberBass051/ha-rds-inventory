# Scan Exceptions

This file tracks every Checkov/Trivy check deliberately skipped in CI, why,
and when it should be revisited. A skip without an entry here is a bug, not
a decision — every `skip_check` in the workflow should have a matching row.

| Check ID | Resource(s) | Reason | Status | Revisit when |
|---|---|---|---|---|
| `CKV2_AWS_5` | `aws_security_group.lambda`, `aws_security_group.proxy`, `aws_security_group.db` | Security groups are provisioned in the `networking` module ahead of the resources that consume them (write Lambda, RDS Proxy, Aurora cluster), which don't exist yet. Checkov correctly flags them as unattached — this is a sequencing artifact of building infrastructure bottom-up, not a design gap. | Temporary | Remove once `database`, `proxy`, and `write-lambda` modules exist and reference these security group IDs. |

## Exceptions considered and rejected

Checks that were flagged, evaluated, and fixed rather than skipped — listed
here so the reasoning isn't lost, and so nobody re-proposes skipping them later.

| Check ID | Why it was fixed instead of skipped |
|---|---|
| `CKV_AWS_23` | Missing SG rule descriptions — trivial to fix, and the description itself documents the Lambda → Proxy → DB access chain directly in the AWS console. |
| `CKV2_AWS_12` | Default VPC security group left in its allow-all state — a real gap contradicting the project's explicit-access design. Fixed via `aws_default_security_group` with all rules stripped. See [ADR 0002](./adr/0002-security-group-hardening.md). |
| `CKV2_AWS_11` | No VPC flow logs — a real visibility gap, not a false positive. Fixed by adding a flow log, CloudWatch log group, and dedicated IAM role. |