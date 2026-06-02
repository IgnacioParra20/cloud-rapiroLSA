import json
import os
import time
from decimal import Decimal

import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])


def handler(event, context):
    print("Evento recibido:", json.dumps(event))

    session_id = event.get("SessionId", "lambda-session-test")
    detected_sign = event.get("DetectedSign", "Hola")
    confidence = Decimal(str(event.get("Confidence", 0.94)))
    source = event.get("Source", "AWS Lambda")
    timestamp = int(time.time())

    item = {
        "SessionId": session_id,
        "Timestamp": timestamp,
        "DetectedSign": detected_sign,
        "Confidence": confidence,
        "Source": source
    }

    table.put_item(Item=item)

    response = {
        "message": "Registro guardado correctamente en DynamoDB",
        "item": {
            "SessionId": session_id,
            "Timestamp": timestamp,
            "DetectedSign": detected_sign,
            "Confidence": float(confidence),
            "Source": source
        }
    }

    return {
        "statusCode": 200,
        "body": json.dumps(response)
    }