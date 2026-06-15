#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/rapiro-lsa-user-data.log | logger -t rapiro-lsa-user-data -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3 python3-pip python3-venv git curl wget ca-certificates

APP_DIR="/opt/rapiro-lsa"
mkdir -p "$${APP_DIR}/ec2_app"

cat > "$${APP_DIR}/ec2_app/main.py" <<'PYAPP'
${main_py}
PYAPP

cat > "$${APP_DIR}/ec2_app/requirements.txt" <<'REQAPP'
${requirements_txt}
REQAPP

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

cat > /etc/systemd/system/rapiro-lsa-backend.service <<'SERVICE'
[Unit]
Description=RAPIRO-LSA EC2 FastAPI backend
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/rapiro-lsa/ec2_app
EnvironmentFile=/opt/rapiro-lsa/backend.env
ExecStart=/opt/rapiro-lsa/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5
User=root
StandardOutput=append:/var/log/rapiro-lsa-backend.log
StandardError=append:/var/log/rapiro-lsa-backend.log

[Install]
WantedBy=multi-user.target
SERVICE

touch /var/log/rapiro-lsa-backend.log

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
            "file_path": "/var/log/rapiro-lsa-backend.log",
            "log_group_name": "/rapiro-lsa/ec2-backend/${aws_region}",
            "log_stream_name": "{instance_id}/backend",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/rapiro-lsa-user-data.log",
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
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

systemctl daemon-reload
systemctl enable rapiro-lsa-backend.service
systemctl start rapiro-lsa-backend.service
