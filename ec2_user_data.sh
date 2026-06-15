#!/bin/bash
mkdir -p /opt/rapiro-lsa
set -euxo pipefail
exec > >(tee -a /opt/rapiro-lsa/user-data-debug.log | logger -t rapiro-lsa-user-data -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive
APP_DIR="/opt/rapiro-lsa"
BACKEND_LOG="$${APP_DIR}/backend.log"

apt-get update -y
apt-get install -y python3 python3-pip python3-venv git curl wget ca-certificates iproute2 procps

mkdir -p "$${APP_DIR}/ec2_app" "$${APP_DIR}/scripts"
touch "$${BACKEND_LOG}"

cat > "$${APP_DIR}/ec2_app/main.py" <<'PYAPP'
${main_py}
PYAPP

cat > "$${APP_DIR}/ec2_app/requirements.txt" <<'REQAPP'
${requirements_txt}
REQAPP

cat > "$${APP_DIR}/ec2_app/requirements-vision.txt" <<'REQVISION'
${requirements_vision_txt}
REQVISION

cat > "$${APP_DIR}/scripts/ec2_diagnose.sh" <<'DIAG'
${ec2_diagnose_sh}
DIAG

cat > "$${APP_DIR}/scripts/ec2_restart_backend.sh" <<'RESTART'
${ec2_restart_backend_sh}
RESTART
chmod +x "$${APP_DIR}/scripts/ec2_diagnose.sh" "$${APP_DIR}/scripts/ec2_restart_backend.sh"

cat > "$${APP_DIR}/backend.env" <<'ENVAPP'
DYNAMODB_TABLE=${dynamodb_table}
S3_BUCKET=${s3_bucket}
S3_EVENTS_PREFIX=${s3_events_prefix}
AWS_REGION=${aws_region}
API_TOKEN=${api_token}
ENVAPP
chmod 600 "$${APP_DIR}/backend.env"

python3 -m venv "$${APP_DIR}/venv"
"$${APP_DIR}/venv/bin/pip" install --upgrade pip
"$${APP_DIR}/venv/bin/pip" install -r "$${APP_DIR}/ec2_app/requirements.txt"
# MediaPipe is optional. A failure here must not block /health or /event.
"$${APP_DIR}/venv/bin/pip" install -r "$${APP_DIR}/ec2_app/requirements-vision.txt" || echo "Optional vision dependencies failed; continuing with mock /frame"

cat > /etc/systemd/system/rapiro-lsa-backend.service <<'SERVICE'
[Unit]
Description=RAPIRO LSA EC2 FastAPI Backend
After=network.target

[Service]
WorkingDirectory=/opt/rapiro-lsa/ec2_app
EnvironmentFile=/opt/rapiro-lsa/backend.env
ExecStart=/opt/rapiro-lsa/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5
User=root
StandardOutput=append:/opt/rapiro-lsa/backend.log
StandardError=append:/opt/rapiro-lsa/backend.log

[Install]
WantedBy=multi-user.target
SERVICE

if command -v systemctl >/dev/null 2>&1; then
  echo "Starting backend through systemd"
  systemctl daemon-reload
  systemctl enable rapiro-lsa-backend.service
  systemctl restart rapiro-lsa-backend.service
else
  echo "systemctl not found; starting backend through nohup fallback"
  cd "$${APP_DIR}/ec2_app"
  set -a
  . "$${APP_DIR}/backend.env"
  set +a
  nohup "$${APP_DIR}/venv/bin/python" -m uvicorn main:app --host 0.0.0.0 --port 8000 >> "$${BACKEND_LOG}" 2>&1 &
fi

# CloudWatch Agent is useful, but it must never prevent backend startup.
(
  CW_AGENT_DEB="/tmp/amazon-cloudwatch-agent.deb"
  wget -q -O "$${CW_AGENT_DEB}" "https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
  dpkg -i "$${CW_AGENT_DEB}"
  mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
  cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/opt/rapiro-lsa/backend.log",
            "log_group_name": "/rapiro-lsa/ec2-backend/${aws_region}",
            "log_stream_name": "{instance_id}/backend",
            "retention_in_days": 7
          },
          {
            "file_path": "/opt/rapiro-lsa/user-data-debug.log",
            "log_group_name": "/rapiro-lsa/ec2-backend/${aws_region}",
            "log_stream_name": "{instance_id}/user-data",
            "retention_in_days": 7
          }
        ]
      }
    }
  }
}
CWCONFIG
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
) || echo "CloudWatch Agent setup failed; backend remains available"

sleep 3
curl -v http://localhost:8000/health || true
