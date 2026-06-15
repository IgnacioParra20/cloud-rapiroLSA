"""Compatibility module for legacy CI checks.

The production cloud path no longer uses AWS Lambda. The active backend lives in
``ec2_app/main.py`` and is deployed on EC2. This module remains intentionally
minimal so older validation commands that compile ``lambda/app.py`` keep working
while Terraform no longer provisions Lambda resources.
"""


def handler(event, context):
    return {
        "statusCode": 410,
        "headers": {"Content-Type": "application/json"},
        "body": '{"error":"Lambda backend removed; use the EC2 FastAPI backend"}',
    }
