# RAPIRO-LSA EC2 Backend

Backend FastAPI para procesamiento continuo de frames JPEG en EC2. Recibe frames desde RAPIRO/Raspberry, decodifica con OpenCV, extrae keypoints con MediaPipe Hands y deja listo el punto de integración `predict_sign(keypoints)` para conectar el modelo real.

## Endpoints

- `GET /health`: health check.
- `POST /event`: registra un evento reconocido manualmente.
- `POST /frame`: recibe multipart/form-data con `SessionId`, `DeviceId`, `Mode` y archivo `frame` JPEG.

## Variables de entorno

- `DYNAMODB_TABLE`
- `S3_BUCKET`
- `S3_EVENTS_PREFIX=events/`
- `AWS_REGION=sa-east-1`
- `API_TOKEN`
