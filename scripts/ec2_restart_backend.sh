#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/rapiro-lsa"
APP_MODULE_DIR="${APP_DIR}/ec2_app"
VENV_PYTHON="${APP_DIR}/venv/bin/python"
LOG_FILE="${APP_DIR}/backend.log"
ENV_FILE="${APP_DIR}/backend.env"

mkdir -p "${APP_DIR}"
touch "${LOG_FILE}"

echo "[$(date -Is)] Restarting RAPIRO-LSA backend" | tee -a "${LOG_FILE}"

if pgrep -f "uvicorn main:app" >/dev/null 2>&1; then
  pkill -f "uvicorn main:app" || true
  sleep 2
fi

cd "${APP_MODULE_DIR}"
set -a
# shellcheck disable=SC1090
. "${ENV_FILE}"
set +a

nohup "${VENV_PYTHON}" -m uvicorn main:app --host 0.0.0.0 --port 8000 >> "${LOG_FILE}" 2>&1 &
BACKEND_PID=$!
echo "[$(date -Is)] Started uvicorn with PID ${BACKEND_PID}" | tee -a "${LOG_FILE}"

sleep 3
curl -v http://localhost:8000/health
