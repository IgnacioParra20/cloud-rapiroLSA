import json
import os
import sys
import time
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def require_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"ERROR: falta variable de entorno {name}")
    return value


def request_json(method: str, url: str, token: str = "", payload: dict[str, Any] | None = None) -> dict[str, Any]:
    body = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {"Accept": "application/json"}
    if payload is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["x-api-key"] = token

    req = Request(url, data=body, headers=headers, method=method)
    try:
        with urlopen(req, timeout=15) as response:
            raw = response.read().decode("utf-8")
            print(f"{method} {url} -> HTTP {response.status}")
            print(raw)
            return json.loads(raw) if raw else {}
    except HTTPError as exc:
        error_body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"ERROR HTTP en {method} {url}: {exc.code}\n{error_body}") from exc
    except URLError as exc:
        raise SystemExit(f"ERROR de conexión en {method} {url}: {exc.reason}") from exc
    except TimeoutError as exc:
        raise SystemExit(f"ERROR timeout en {method} {url}") from exc


def main() -> None:
    base_url = require_env("RAPIRO_EC2_BACKEND_URL").rstrip("/")
    token = os.environ.get("RAPIRO_API_TOKEN", "").strip()

    health = request_json("GET", f"{base_url}/health")
    if health.get("status") != "ok" or health.get("service") != "rapiro-lsa-ec2-backend":
        raise SystemExit(f"ERROR: respuesta inesperada de /health: {health}")

    event_payload = {
        "SessionId": f"ec2-basic-test-{int(time.time())}",
        "DetectedSign": "Hola",
        "Confidence": 0.95,
        "Source": "PowerShell Test",
        "DeviceId": "rapiro-lsa-ec2",
        "Mode": "word",
    }
    event = request_json("POST", f"{base_url}/event", token=token, payload=event_payload)
    if "event" not in event or "s3_path" not in event:
        raise SystemExit(f"ERROR: respuesta inesperada de /event: {event}")

    print("OK: /health y /event respondieron correctamente")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit("Interrumpido por el usuario")
