import json
import os
import time
from decimal import Decimal

import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])

polly = boto3.client("polly")
s3 = boto3.client("s3")

S3_BUCKET = os.environ["S3_BUCKET"]


def handler(event, context):
    print("Evento recibido:", json.dumps(event))

    session_id = event.get("SessionId", "lambda-session-test")
    detected_sign = event.get("DetectedSign", "Hola")
    confidence = Decimal(str(event.get("Confidence", 0.94)))
    source = event.get("Source", "AWS Lambda")
    timestamp = int(time.time())

    text_to_speech = f"La seña detectada fue {detected_sign}."

    item = {
        "SessionId": session_id,
        "Timestamp": timestamp,
        "DetectedSign": detected_sign,
        "Confidence": confidence,
        "Source": source,
        "AudioText": text_to_speech
    }

    table.put_item(Item=item)

    polly_response = polly.synthesize_speech(
        Text=text_to_speech,
        OutputFormat="mp3",
        VoiceId="Lupe"
    )

    audio_key = f"audio/{session_id}-{timestamp}.mp3"

    s3.put_object(
        Bucket=S3_BUCKET,
        Key=audio_key,
        Body=polly_response["AudioStream"].read(),
        ContentType="audio/mpeg"
    )

    response = {
        "message": "Inferencia simulada guardada, audio generado con Polly y subido a S3",
        "item": {
            "SessionId": session_id,
            "Timestamp": timestamp,
            "DetectedSign": detected_sign,
            "Confidence": float(confidence),
            "Source": source,
            "AudioText": text_to_speech
        },
        "audio_s3_path": f"s3://{S3_BUCKET}/{audio_key}"
    }

    return {
        "statusCode": 200,
        "body": json.dumps(response)
    }