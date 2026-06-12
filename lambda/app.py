import base64
import json
import os
import time
from decimal import Decimal

import boto3

DYNAMODB_TABLE = os.environ["DYNAMODB_TABLE"]
S3_BUCKET = os.environ["S3_BUCKET"]
API_TOKEN = os.environ.get("API_TOKEN", "")
S3_EVENTS_PREFIX = os.environ.get("S3_EVENTS_PREFIX", "events/")

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(DYNAMODB_TABLE)
s3 = boto3.client("s3")


def build_response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, ensure_ascii=False),
    }


def parse_payload(event):
    if not isinstance(event, dict):
        return {}

    if "body" not in event:
        return event

    body = event.get("body") or "{}"

    if event.get("isBase64Encoded"):
        body = base64.b64decode(body).decode("utf-8")

    if isinstance(body, str):
        return json.loads(body)

    return body


def normalize_headers(event):
    if not isinstance(event, dict):
        return {}

    headers = event.get("headers") or {}
    return {str(key).lower(): value for key, value in headers.items()}


def handler(event, context):
    print("Evento recibido:", json.dumps(event, ensure_ascii=False, default=str))

    headers = normalize_headers(event)

    if API_TOKEN:
        received_token = headers.get("x-api-key")
        if received_token != API_TOKEN:
            print("Token inválido o ausente")
            return build_response(401, {"error": "Token inválido"})

    try:
        payload = parse_payload(event)
        print("Payload parseado:", json.dumps(payload, ensure_ascii=False, default=str))

        session_id = payload.get("SessionId", "rapiro-session-test")
        detected_sign = payload.get("DetectedSign", "unknown")
        confidence = Decimal(str(payload.get("Confidence", 0)))
        source = payload.get("Source", "RAPIRO Local")
        device_id = payload.get("DeviceId", "rapiro-lsa-thing")
        mode = payload.get("Mode", "word")
        timestamp = int(time.time())

        item = {
            "SessionId": session_id,
            "Timestamp": timestamp,
            "DetectedSign": detected_sign,
            "Confidence": confidence,
            "Source": source,
            "DeviceId": device_id,
            "Mode": mode,
        }

        table.put_item(Item=item)
        print("Evento guardado en DynamoDB")

        s3_event = {
            "SessionId": session_id,
            "Timestamp": timestamp,
            "DetectedSign": detected_sign,
            "Confidence": float(confidence),
            "Source": source,
            "DeviceId": device_id,
            "Mode": mode,
        }

        s3_key = f"{S3_EVENTS_PREFIX}{session_id}-{timestamp}.json"

        s3.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=json.dumps(s3_event, ensure_ascii=False).encode("utf-8"),
            ContentType="application/json",
        )
        print(f"Evento guardado en S3: s3://{S3_BUCKET}/{s3_key}")

        return build_response(
            200,
            {
                "message": "Evento recibido y registrado correctamente",
                "event": s3_event,
                "s3_path": f"s3://{S3_BUCKET}/{s3_key}",
            },
        )

    except Exception as exc:
        print("Error procesando evento:", str(exc))
        return build_response(
            500,
            {
                "error": "Error procesando evento",
                "detail": str(exc),
            },
        )
