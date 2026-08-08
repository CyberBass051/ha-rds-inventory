import os
import json
import boto3
import psycopg2

secrets_client = boto3.client("secretsmanager")

def lambda_handler(event, context):
    secret_arn = os.environ["MASTER_SECRET"]
    print(f"Fetching secret from {secret_arn}")
    secret = json.loads(
        secrets_client.get_secret_value(SecretId=secret_arn)["SecretString"]
    )
    print("Secret retrieved. Attempting DB connection...")

    try:
        conn = psycopg2.connect(
            host=os.environ["DB_HOST"],
            dbname=os.environ["DB_NAME"],
            user=secret["username"],
            password=secret["password"],
            sslmode="require",
            connect_timeout=10,
        )
        print("Connection established")
    except Exception as e:
        print(f"Connection failed: {type(e).__name__}: {e}")
        raise

    conn.autocommit = True
    cur = conn.cursor()

    with open("schema.sql", "r") as f:
        schema_sql = f.read()

    print("Applying schema...")
    cur.execute(schema_sql)
    print("Schema applied successfully")

    cur.close()
    conn.close()

    return {"statusCode": 200, "body": "Schema migration complete"}