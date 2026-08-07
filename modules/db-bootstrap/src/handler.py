# modules/db-bootstrap/src/handler.py

import os
import json
import boto3
import psycopg2

secrets_client = boto3.client("secretsmanager")

def lambda_handler(event, context):
    secret = json.loads(
        secrets_client.get_secret_value(SecretId=os.environ["MASTER_SECRET"])["SecretString"]
    )

    conn = psycopg2.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=secret["username"],
        password=secret["password"],
        sslmode="require",
    )
    conn.autocommit = True
    cur = conn.cursor()

    role_name = os.environ["APP_ROLE_NAME"]

    # Idempotent: skip creation if the role already exists (safe to re-run)
    cur.execute("SELECT 1 FROM pg_roles WHERE rolname = %s", (role_name,))
    if cur.fetchone() is None:
        cur.execute(f"CREATE ROLE {role_name} WITH LOGIN;")

    # Grant IAM authentication to this role
    cur.execute(f"GRANT rds_iam TO {role_name};")

    # Least-privilege grants — only what the write path in inventory.sql needs
    cur.execute(f"GRANT SELECT, UPDATE ON inventory TO {role_name};")
    cur.execute(f"GRANT SELECT, INSERT ON orders TO {role_name};")
    cur.execute(f"GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO {role_name};")

    cur.close()
    conn.close()

    return {"statusCode": 200, "body": f"Bootstrapped role {role_name}"}