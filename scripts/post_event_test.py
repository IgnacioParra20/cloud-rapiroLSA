import os

import requests

url = os.environ["RAPIRO_LAMBDA_URL"]
token = os.environ["RAPIRO_API_TOKEN"]

payload = {
    "SessionId": "http-test-001",
    "DetectedSign": "Hola",
    "Confidence": 0.98,
    "Source": "Python Local Test",
    "DeviceId": "rapiro-lsa-thing",
    "Mode": "word",
}

response = requests.post(
    url,
    headers={"x-api-key": token},
    json=payload,
    timeout=3,
)

print("Status:", response.status_code)
print(response.text)
