import json
import time

def handler(event, context):
    print("Evento recibido:", json.dumps(event))

    response = {
        "message": "Lambda de RAPIRO-LSA funcionando correctamente",
        "detectedSign": "Hola",
        "confidence": 0.94,
        "timestamp": int(time.time())
    }

    return {
        "statusCode": 200,
        "body": json.dumps(response)
    }