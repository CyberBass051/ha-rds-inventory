# Scan Exceptions

| Check ID | Resource(s) | Reason | Status | Revisit when |
|---|---|---|---|---|
| `CKV2_AWS_5` | `aws_security_group.lambda`, `aws_security_group.proxy`, `aws_security_group.db` | SGs provisioned ahead of the resources that consume them (Lambda, Proxy, cluster now exist as of the `database` module — check whether this still fires). | Temporary — verify still needed | Remove once `proxy` and `write-lambda` modules attach these SGs. |
| `CKV_AWS_338` | `aws_cloudwatch_log_group.vpc_flow_logs` | 14-day retention is a deliberate cost/completeness tradeoff for a portfolio project with no production incident-response obligation. | Permanent | N/A |
| `CKV_AWS_139` | `aws_rds_cluster.main` | `deletion_protection = false` — deliberate, so the cluster can be torn down and rebuilt cheaply during iteration and after the failover test concludes. Not a production posture. | Permanent for this project | Revisit only if this project is ever run long-term instead of torn down after demo/testing. |
| `CKV2_AWS_8` | `aws_rds_cluster.main` | Native RDS automated backups (`backup_retention_period = 7`) already provide point-in-time recovery. AWS Backup adds a centralized backup-orchestration layer valuable across multiple services/accounts — unjustified overhead for a single-cluster portfolio project with no cross-service backup story. | Permanent for this project | Revisit if this project's scope grows to include multiple data stores needing unified backup policy. |

## Exceptions considered and rejected

| Check ID | Why it was fixed instead of skipped |
|---|---|
| `CKV_AWS_23` | Missing SG rule descriptions — fixed, doubles as inline documentation of the access chain. |
| `CKV2_AWS_12` | Default VPC SG left allow-all — fixed via `aws_default_security_group` with all rules stripped. See ADR 0002. |
| `CKV2_AWS_11` | No VPC flow logs — fixed with flow log, log group, dedicated IAM role. |
| `CKV_AWS_158` | CloudWatch log groups (flow logs, then RDS Postgres logs) not KMS-encrypted — fixed by wiring `kms_key_id` on both. |
| `CKV2_AWS_64` | KMS keys (flow logs, then RDS) had no explicit policy — fixed with explicit policies scoping usage per-service. |
| `CKV_AWS_313` | RDS cluster not copying tags to snapshots — trivial fix. |
| `CKV_AWS_226` | Auto minor version upgrade not explicit — fixed on both instances. |
| `CKV_AWS_162` | Cluster-level IAM auth was missing — this was a real gap in the RDS Proxy IAM-auth design, not just a scanner nitpick. Fixed by enabling `iam_database_authentication_enabled`. |
| `CKV_AWS_353` | Performance Insights disabled — fixed, directly useful for the failover test's evidence. |
| `CKV_AWS_118` | Enhanced Monitoring disabled — fixed with a dedicated monitoring IAM role. |
| `CKV2_AWS_27` | Query logging not enabled — fixed via `log_statement`/`log_min_duration_statement` parameters on the cluster parameter group. |