ADR 0006: RDS Proxy end-to-end IAM auth requires rds-db:connect on the caller's role, not the Proxy's own role
Status

Accepted

Context

app_user's registered secret on RDS Proxy has "IAM authentication: Required" set (see ADR 0005). This setting forces the Proxy's DefaultAuthScheme into end-to-end IAM mode (IAM_AUTH) — attempting to leave DefaultAuthScheme on NONE (AWS's "standard IAM authentication," where the Proxy→database leg uses the secret's stored password) is rejected outright by RDS Proxy with: "RDS Proxy can't connect to the database because IAM authentication isn't set as the default authentication scheme. Set DefaultAuthScheme to IAM_AUTH." This is not documented plainly in AWS's own IAM-auth-for-Proxy guide or in the community troubleshooting threads searched during debugging — the interaction between a per-secret "Required" override and the proxy-wide default scheme had to be discovered empirically.

With DefaultAuthScheme = IAM_AUTH, the Proxy performs a second, separate IAM-authenticated connection on the Proxy→database leg (distinct from the client→Proxy leg, which write-lambda's own generate_db_auth_token() call already handles). This second leg failed repeatedly with:

The new database connection using IAM authentication failed. Error code: [XX000].
Message: Request returned an error: PAM authentication failed for user "app_user".

This happened despite independently confirmed, correct Postgres-side state (app_user exists, rolcanlogin = true, pg_has_role('app_user', 'rds_iam', 'member') = true) — ruling out a database-side cause. Two IAM policy attempts were made before finding the actual fix:

rds-db:connect scoped to the Proxy's own resource ID (prx-...), on the Proxy's own execution role — no effect, identical error
rds-db:connect scoped to the cluster's resource ID (cluster-...), still on the Proxy's own execution role — also no effect, identical error, byte-for-byte

Both attempts assumed the Proxy generates its own token for the backend leg using its own service role's identity. That assumption was wrong.

Decision

Grant both rds-db:connect permissions — one scoped to the Proxy's resource ID, one scoped to the cluster's resource ID — on ha-rds-write-lambda-role (the actual calling Lambda's execution role), not on the Proxy's own IAM role:

json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowConnectViaProxy",
      "Effect": "Allow",
      "Action": "rds-db:connect",
      "Resource": "arn:aws:rds-db:us-east-1:221717898536:dbuser:prx-0ca08f1f57ff57597/app_user"
    },
    {
      "Sid": "AllowConnectToClusterEndToEnd",
      "Effect": "Allow",
      "Action": "rds-db:connect",
      "Resource": "arn:aws:rds-db:us-east-1:221717898536:dbuser:cluster-C5SBOGEAF3KIJ56YD6UOCB5AKM/app_user"
    }
  ]
}

This resolved the failure on the first retry. The conclusion: under RDS Proxy's end-to-end IAM mode, authorization for both hops (client→Proxy and Proxy→database) is evaluated against the original caller's IAM identity, not the Proxy's own service-linked role. The Proxy forwards/re-derives the caller's authorization rather than minting backend tokens under its own identity.

Consequences
Every Lambda (or other caller) that connects through this Proxy under IAM_AUTH mode needs two rds-db:connect statements on its own execution role — one per resource ID (Proxy and cluster) — not one. This is easy to under-provision and will surface as the exact same generic PAM authentication failed error with no indication of which identity or resource is actually missing the grant.
The Proxy's own execution role's permissions (beyond secretsmanager:GetSecretValue) are not the relevant place to grant backend database access in this mode — a reasonable-looking fix that does nothing, costing real debugging time if not already known.
DefaultAuthScheme = NONE is not available as a fallback once any registered secret on the Proxy has "IAM authentication: Required" set — the two settings are coupled, not independent toggles as the console UI's layout might suggest.
This behavior is not clearly documented in AWS's official RDS Proxy IAM setup guide as of this writing; this ADR exists partly to record it for future reference, since reproducing the discovery cost roughly five debugging iterations across SG rules, IAM ARNs, and auth-scheme toggles.
