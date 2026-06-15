import argparse
import os
from pathlib import Path

import requests


def build_headers(token: str) -> dict[str, str]:
    return {"x-api-key": token} if token else {}


def main() -> None:
    parser = argparse.ArgumentParser(description="Prueba el backend EC2 FastAPI de RAPIRO-LSA")
    parser.add_argument("frame", nargs="?", help="Ruta opcional a una imagen JPEG para probar POST /frame")
    args = parser.parse_args()

    base_url = os.environ["RAPIRO_EC2_BACKEND_URL"].rstrip("/")
    token = os.environ.get("RAPIRO_API_TOKEN", "")
    headers = build_headers(token)

    health_response = requests.get(f"{base_url}/health", timeout=5)
    print("GET /health:", health_response.status_code, health_response.text)
    health_response.raise_for_status()

    event_payload = {
        "SessionId": "ec2-manual-test-001",
        "DetectedSign": "Hola",
        "Confidence": 0.93,
        "DeviceId": "rapiro-lsa-thing-sae1",
        "Mode": "word",
        "Source": "scripts/test_ec2_backend.py",
        "Stable": True,
    }
    event_response = requests.post(f"{base_url}/event", headers=headers, json=event_payload, timeout=10)
    print("POST /event:", event_response.status_code, event_response.text)
    event_response.raise_for_status()

    if args.frame:
        frame_path = Path(args.frame)
        with frame_path.open("rb") as frame_file:
            frame_response = requests.post(
                f"{base_url}/frame",
                headers=headers,
                data={
                    "SessionId": "ec2-frame-test-001",
                    "DeviceId": "rapiro-lsa-thing-sae1",
                    "Mode": "word",
                },
                files={"frame": (frame_path.name, frame_file, "image/jpeg")},
                timeout=15,
            )
        print("POST /frame:", frame_response.status_code, frame_response.text)
        frame_response.raise_for_status()


if __name__ == "__main__":
    main()
