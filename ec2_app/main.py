import json
import logging
import os
import time
from collections import defaultdict, deque
from decimal import Decimal
from typing import Any

import boto3
import cv2
import numpy as np
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from pydantic import BaseModel, Field

try:
    import mediapipe as mp

    MEDIAPIPE_AVAILABLE = True
except Exception as exc:  # MediaPipe is optional for the basic cloud smoke test.
    mp = None
    MEDIAPIPE_AVAILABLE = False
    MEDIAPIPE_IMPORT_ERROR = str(exc)
else:
    MEDIAPIPE_IMPORT_ERROR = ""

SERVICE_NAME = "rapiro-lsa-ec2-backend"
DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE", "")
S3_BUCKET = os.environ.get("S3_BUCKET", "")
S3_EVENTS_PREFIX = os.environ.get("S3_EVENTS_PREFIX", "events/")
AWS_REGION = os.environ.get("AWS_REGION", "sa-east-1")
API_TOKEN = os.environ.get("API_TOKEN", "")
STABILITY_WINDOW = int(os.environ.get("STABILITY_WINDOW", "3"))
STABILITY_MIN_CONFIDENCE = float(os.environ.get("STABILITY_MIN_CONFIDENCE", "0.85"))

logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(SERVICE_NAME)

app = FastAPI(title="RAPIRO-LSA EC2 Backend", version="1.0.0")

dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION) if DYNAMODB_TABLE else None
table = dynamodb.Table(DYNAMODB_TABLE) if dynamodb else None
s3 = boto3.client("s3", region_name=AWS_REGION) if S3_BUCKET else None

if MEDIAPIPE_AVAILABLE:
    mp_hands = mp.solutions.hands
    hands = mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=1,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    )
else:
    hands = None
    logger.warning("MediaPipe unavailable; /frame will use mock recognition: %s", MEDIAPIPE_IMPORT_ERROR)

session_predictions: dict[str, deque[str]] = defaultdict(lambda: deque(maxlen=STABILITY_WINDOW))
last_registered: dict[str, tuple[str, int]] = {}


class EventRequest(BaseModel):
    SessionId: str = Field(default="manual-test-001")
    DetectedSign: str = Field(default="Hola")
    Confidence: float = Field(default=0.9, ge=0, le=1)
    DeviceId: str = Field(default="rapiro-lsa-ec2")
    Mode: str = Field(default="word")
    Source: str = Field(default="EC2 Manual Test")
    Stable: bool = Field(default=True)


class RecognitionResponse(BaseModel):
    SessionId: str
    DetectedSign: str
    Confidence: float
    Stable: bool
    Message: str
    MediaPipeAvailable: bool


def require_api_key(x_api_key: str | None = Header(default=None)) -> None:
    if API_TOKEN and x_api_key != API_TOKEN:
        logger.warning("Request rejected because x-api-key is invalid or missing")
        raise HTTPException(status_code=401, detail="Token inválido")


def decode_jpeg(frame_bytes: bytes) -> np.ndarray:
    np_buffer = np.frombuffer(frame_bytes, np.uint8)
    image = cv2.imdecode(np_buffer, cv2.IMREAD_COLOR)
    if image is None:
        raise HTTPException(status_code=400, detail="No se pudo decodificar el frame JPEG")
    return image


def extract_hand_keypoints(image_bgr: np.ndarray) -> list[float]:
    if hands is None:
        return []

    image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    results = hands.process(image_rgb)
    if not results.multi_hand_landmarks:
        return []

    landmarks = results.multi_hand_landmarks[0].landmark
    keypoints: list[float] = []
    for landmark in landmarks:
        keypoints.extend([landmark.x, landmark.y, landmark.z])
    return keypoints


def predict_sign(keypoints: list[float]) -> tuple[str, float, str]:
    if not MEDIAPIPE_AVAILABLE:
        return "Hola", 0.90, "mock: MediaPipe no está instalado; backend básico operativo"
    if not keypoints:
        return "unknown", 0.0, "MediaPipe disponible, pero no se detectó mano"
    return "Hola", 0.90, "mock: mano detectada; conectar modelo IA real en predict_sign()"


def update_stability(session_id: str, detected_sign: str, confidence: float) -> bool:
    if detected_sign == "unknown" or confidence < STABILITY_MIN_CONFIDENCE:
        session_predictions[session_id].clear()
        return False

    predictions = session_predictions[session_id]
    predictions.append(detected_sign)
    return len(predictions) == STABILITY_WINDOW and len(set(predictions)) == 1


def should_register_event(session_id: str, detected_sign: str, timestamp: int) -> bool:
    last_sign, last_timestamp = last_registered.get(session_id, ("", 0))
    if last_sign == detected_sign and timestamp - last_timestamp < 2:
        return False
    last_registered[session_id] = (detected_sign, timestamp)
    return True


def decimalize(value: Any) -> Any:
    if isinstance(value, float):
        return Decimal(str(value))
    if isinstance(value, dict):
        return {key: decimalize(inner_value) for key, inner_value in value.items()}
    if isinstance(value, list):
        return [decimalize(item) for item in value]
    return value


def register_event(event: dict[str, Any]) -> str:
    if table is None or s3 is None:
        raise HTTPException(status_code=500, detail="DYNAMODB_TABLE y S3_BUCKET deben estar configurados")

    table.put_item(Item=decimalize(event))
    s3_key = f"{S3_EVENTS_PREFIX}{event['SessionId']}-{event['Timestamp']}.json"
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=s3_key,
        Body=json.dumps(event, ensure_ascii=False).encode("utf-8"),
        ContentType="application/json",
    )
    logger.info("Registered event in DynamoDB and s3://%s/%s", S3_BUCKET, s3_key)
    return f"s3://{S3_BUCKET}/{s3_key}"


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": SERVICE_NAME}


@app.post("/event")
def event(payload: EventRequest, _: None = Depends(require_api_key)) -> dict[str, Any]:
    event_payload = payload.model_dump()
    event_payload["Timestamp"] = int(time.time())
    event_payload["Source"] = payload.Source or "EC2 Manual Test"
    s3_path = register_event(event_payload)
    return {"message": "Evento registrado correctamente", "event": event_payload, "s3_path": s3_path}


@app.post("/frame", response_model=RecognitionResponse)
async def frame(
    SessionId: str = Form(...),
    DeviceId: str = Form(...),
    Mode: str = Form(default="word"),
    frame_file: UploadFile = File(..., alias="frame"),
    _: None = Depends(require_api_key),
) -> RecognitionResponse:
    frame_bytes = await frame_file.read()
    image = decode_jpeg(frame_bytes)
    keypoints = extract_hand_keypoints(image)
    detected_sign, confidence, detail = predict_sign(keypoints)
    stable = update_stability(SessionId, detected_sign, confidence)

    timestamp = int(time.time())
    message = "Seña reconocida correctamente" if stable else f"Esperando detección estable ({detail})"

    if stable and should_register_event(SessionId, detected_sign, timestamp):
        register_event(
            {
                "SessionId": SessionId,
                "Timestamp": timestamp,
                "DetectedSign": detected_sign,
                "Confidence": confidence,
                "Stable": stable,
                "Source": "EC2 FastAPI Frame Processing",
                "DeviceId": DeviceId,
                "Mode": Mode,
                "KeypointsCount": len(keypoints),
                "MediaPipeAvailable": MEDIAPIPE_AVAILABLE,
            }
        )

    logger.info(
        "Frame processed session=%s device=%s sign=%s confidence=%.2f stable=%s keypoints=%s mediapipe=%s",
        SessionId,
        DeviceId,
        detected_sign,
        confidence,
        stable,
        len(keypoints),
        MEDIAPIPE_AVAILABLE,
    )
    return RecognitionResponse(
        SessionId=SessionId,
        DetectedSign=detected_sign,
        Confidence=confidence,
        Stable=stable,
        Message=message,
        MediaPipeAvailable=MEDIAPIPE_AVAILABLE,
    )
