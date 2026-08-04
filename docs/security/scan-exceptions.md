# Scan Exceptions

This file tracks every Checkov/Trivy check deliberately skipped in CI, why,
and when it should be revisited. A skip without an entry here is a bug, not
a decision — every `skip_check` in the workflow should have a matching row.

| Check ID | Resource(s) | Reason | Status | Revisit when |
|---|---|---|---|---|
| `CKV2_AWS_5` | `aws_security_group.lambda`, `aws_security_group.proxy`, `aws_security_group.db` | Security groups are provisioned in the `networking` module ahead of the resources that consume them (write Lambda, RDS Proxy, Aurora cluster), which don't exist yet. Checkov correctly flags them as unattached — this is a sequencing artifact of building infrastructure bottom-up, not a design gap. | Temporary | Remove once `database`, `proxy`, and `write-lambda` modules exist and reference these security group IDs. |
| `CKV_AWS_338` | `aws_cloudwatch_log_group.vpc_flow_logs` | 14-day retention is a deliberate cost/completeness tradeoff for a portfolio project with no production incident-response obligation; production environments would typically retain 30-90+ days. | Permanent | N/A — revisit only if this project's scope changes to simulate a production SLA. |
| `CKV_AWS_324` *(anticipated)* | `aws_rds_cluster.main` | `deletion_protection = false` — set deliberately so the cluster can be torn down and rebuilt cheaply during iteration and after the failover test concludes. Not a production posture. | Anticipated | Confirm once `database` module runs through CI; revisit if this project is ever left running long-term instead of torn down after demo/testing. |
| `CKV_AWS_150` *(anticipated)* | `aws_rds_cluster.main` | `skip_final_snapshot = true` — same rationale as above; avoids leaving an orphaned snapshot (and its storage cost) behind every time this project is destroyed and rebuilt. | Anticipated | Same as above. |

## Exceptions considered and rejected

Checks that were flagged, evaluated, and fixed rather than skipped — listed
here so the reasoning isn't lost, and so nobody re-proposes skipping them later.

| Check ID | Why it was fixed instead of skipped |
|---|---|
| `CKV_AWS_23` | Missing SG rule descriptions — trivial to fix, and the description itself documents the Lambda → Proxy → DB access chain directly in the AWS console. |
| `CKV2_AWS_12` | Default VPC security group left in its allow-all state — a real gap contradicting the project's explicit-access design. Fixed via `aws_default_security_group` with all rules stripped. See [ADR 0002](./adr/0002-security-group-hardening.md). |
| `CKV2_AWS_11` | No VPC flow logs — a real visibility gap, not a false positive. Fixed by adding a flow log, CloudWatch log group, and dedicated IAM role. |
| `CKV_AWS_158` | CloudWatch log group not KMS-encrypted — fixed by adding a dedicated KMS key with rotation enabled and wiring `kms_key_id` into the log group. |
| `CKV2_AWS_64` | KMS key had no explicit policy (relying on the implicit default) — fixed with an explicit policy scoping usage to the account root and the CloudWatch Logs service. |