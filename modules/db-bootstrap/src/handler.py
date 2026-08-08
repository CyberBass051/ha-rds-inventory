# modules/db-bootstrap/src/handler.py

import os
import json
import boto3
import psycopg2

secrets_client = boto3.client("secretsmanager")

def lambda_handler(event, context):
    print(f"Fetching secret from {os.environ["MASTER_SECRET"]}")
    secret = json.loads(
        secrets_client.get_secret_value(SecretId=os.environ["MASTER_SECRET"])["SecretString"]
    )
    print("Secret retrieved. Attempting DB connection...")

    try:
        conn = psycopg2.connect(
            host=os.environ["DB_HOST"],
            dbname=os.environ["DB_NAME"],
            user=secret["username"],
            password=secret["password"],
            sslmode="require",
        )
        print("Connection established.")
        conn.autocommit = True
        cur = conn.cursor()

        role_name = os.environ["APP_ROLE_NAME"]

        # Idempotent: skip creation if the role already exists (safe to re-run)
        cur.execute("SELECT 1 FROM pg_roles WHERE rolname = %s", (role_name,))
        if cur.fetchone() is None:
            cur.execute(f"CREATE ROLE {role_name} WITH LOGIN;")

        # Grant IAM authentication to this role
        cur.execute(f"GRANT rds_iam TO {role_name};")

        # Authenticate User
        cur.execute(
            "ALTER ROLE %s WITH PASSWORD %s;",
            (psycopg2.extensions.AsIs(role_name), os.environ["APP_USER_PASSWORD"])
        )

        # Least-privilege grants — only what the write path in inventory.sql needs
        cur.execute(f"GRANT SELECT, UPDATE ON inventory TO {role_name};")
        cur.execute(f"GRANT SELECT, INSERT ON orders TO {role_name};")
        cur.execute(f"GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO {role_name};")

        cur.close()
        conn.close()
    except Exception as e:
        print(f"Connection failed: {type(e).__name__}: {e}")

    

    return {"statusCode": 200, "body": f"Bootstrapped role {role_name}"}