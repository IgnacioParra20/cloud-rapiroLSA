#!/usr/bin/env bash
set -u

echo "== date =="
date

echo "== identity =="
whoami
pwd

echo "== os =="
cat /etc/os-release || true
ps -p 1 -o comm= || true

echo "== binaries =="
which python3 || true
which pip3 || true
which systemctl || true
which journalctl || true

echo "== files =="
ls -la /opt/ || true
ls -la /opt/rapiro-lsa/ || true
ls -la /opt/rapiro-lsa/ec2_app/ || true
ls -la /opt/rapiro-lsa/venv/bin/ || true

echo "== backend.env =="
sudo cat /opt/rapiro-lsa/backend.env || true

echo "== port 8000 =="
sudo ss -tulpn | grep 8000 || true

echo "== health =="
curl -v http://localhost:8000/health || true

echo "== backend.log =="
tail -n 100 /opt/rapiro-lsa/backend.log || true

echo "== user-data-debug.log =="
tail -n 100 /opt/rapiro-lsa/user-data-debug.log || true

echo "== cloud-init-output.log =="
tail -n 100 /var/log/cloud-init-output.log || true
