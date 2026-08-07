# modules/write-lambda/src/handler.py

import os
import json
import boto3
import psycopg2

session = boto3.Session()
rds_client = session.client("rds")

PROXY_ENDPOINT = os.environ["PROXY_ENDPOINT"]
DB_NAME = os.environ["DB_NAME"]
DB_USER = os.environ["DB_USER"]
REGION = os.environ["AWS_REGION_ID"]


def get_iam_auth_token():
    return rds_client.generate_db_auth_token(
        DBHostname=PROXY_ENDPOINT,
        Port=5432,
        DBUsername=DB_USER,
        Region=REGION,
    )


def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
        sku = body.get("sku")
        quantity = body.get("quantity")

        if not sku or not isinstance(quantity, int) or quantity <= 0:
            return _response(400, {"error": "sku and a positive integer quantity are required"})

        token = get_iam_auth_token()

        conn = psycopg2.connect(
            host=PROXY_ENDPOINT,
            port=5432,
            dbname=DB_NAME,
            user=DB_USER,
            password=token,
            sslmode="require",
        )
        conn.autocommit = False
        cur = conn.cursor()

        cur.execute(
            "UPDATE inventory SET stock = stock - %s, version = version + 1, updated_at = now() "
            "WHERE sku = %s AND stock >= %s",
            (quantity, sku, quantity),
        )
        updated = cur.rowcount

        if updated == 0:
            status = "rejected_insufficient_stock"
            cur.execute(
                "INSERT INTO orders (sku, quantity, status) VALUES (%s, %s, %s)",
                (sku, quantity, status),
            )
            conn.commit()
            cur.close()
            conn.close()
            return _response(409, {"status": status, "sku": sku})

        status = "completed"
        cur.execute(
            "INSERT INTO orders (sku, quantity, status) VALUES (%s, %s, %s)",
            (sku, quantity, status),
        )
        conn.commit()
        cur.close()
        conn.close()

        return _response(200, {"status": status, "sku": sku, "quantity": quantity})

    except Exception as e:
        return _response(500, {"error": str(e)})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }