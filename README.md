# cloud-rapiroLSA

Infraestructura cloud del proyecto integrador **RAPIRO-LSA**, implementada en **AWS** con **Terraform**.

El rediseño actual prioriza baja latencia: **RAPIRO/Python detecta la seña y reproduce la voz localmente de forma inmediata**. La nube ya no está en el camino crítico de la respuesta audible; se usa en segundo plano para registro, evidencia y monitoreo.

---

## Arquitectura principal actual: opción C

```text
RAPIRO / Python local
        |
        | 1. Detecta la seña localmente
        | 2. Reproduce audio local inmediato
        | 3. Envía POST HTTP en segundo plano
        v
AWS Lambda Function URL
        |
        v
AWS Lambda rapiro-lsa-inference
        |
        ├── Guarda evento en DynamoDB
        ├── Guarda evidencia JSON en S3 bajo events/
        └── Registra logs en CloudWatch
```

Explicación para defensa:

> RAPIRO realiza la detección de señas localmente mediante Python, MediaPipe y un modelo de IA. Para evitar latencia, la respuesta audible se reproduce localmente. En paralelo, el sistema envía el evento reconocido a AWS mediante una Lambda Function URL. La nube registra el evento en DynamoDB, guarda evidencia en S3 y permite monitoreo mediante CloudWatch. De esta manera, el robot responde rápido y el proyecto mantiene una infraestructura cloud real, simple y defendible.

---

## Cambios clave respecto al diseño anterior

* **La detección se realiza localmente** en RAPIRO/Raspberry Pi/Python.
* **La voz principal se reproduce localmente** para evitar lag.
* **Lambda Function URL** es el nuevo endpoint HTTP principal para enviar eventos ya reconocidos.
* **DynamoDB** guarda los eventos detectados.
* **S3** guarda una copia JSON de cada evento bajo el prefijo `events/`.
* **CloudWatch Logs** permite revisar trazabilidad, errores y evidencia operativa.
* **Amazon Polly** queda como dependencia futura/opcional, pero la Lambda principal ya no lo usa para responder al robot.
* **AWS IoT Core** se conserva como flujo legado/opcional, pero ya no es necesario para probar el flujo principal.

---

## Recursos principales

| Servicio | Recurso | Uso actual |
| --- | --- | --- |
| AWS Lambda | `rapiro-lsa-inference` | Ingesta HTTP liviana de eventos detectados. |
| Lambda Function URL | output `lambda_function_url` | Endpoint principal para POST desde Python/PowerShell. |
| DynamoDB | `rapiro-lsa-sessions` | Historial de eventos por `SessionId` y `Timestamp`. |
| S3 | `rapiro-lsa-models-datasets-295552411532` | Modelos/datasets y evidencia JSON en `events/`. |
| CloudWatch Logs | `/aws/lambda/rapiro-lsa-inference` | Logs de recepción, parseo y persistencia. |
| AWS IoT Core | `rapiro-lsa-thing` y topic `rapiro/lsa/keypoints` | Entrada heredada/opcional. |
| Amazon Polly | Permisos heredados | Uso opcional futuro, fuera del flujo principal. |

---

## Payload HTTP esperado

La Lambda acepta POST JSON desde Lambda Function URL. Si faltan campos, usa valores por defecto razonables.

```json
{
  "SessionId": "session-001",
  "DetectedSign": "Hola",
  "Confidence": 0.96,
  "Source": "RAPIRO Local",
  "DeviceId": "rapiro-lsa-thing",
  "Mode": "word"
}
```

Respuesta esperada:

```json
{
  "message": "Evento recibido y registrado correctamente",
  "event": {
    "SessionId": "session-001",
    "Timestamp": 1780000000,
    "DetectedSign": "Hola",
    "Confidence": 0.96,
    "Source": "RAPIRO Local",
    "DeviceId": "rapiro-lsa-thing",
    "Mode": "word"
  },
  "s3_path": "s3://bucket/events/session-001-1780000000.json"
}
```

---

## Seguridad simple del endpoint

La Function URL usa `authorization_type = "NONE"` para facilitar pruebas desde clientes simples, pero la Lambda valida un token enviado en el header HTTP `x-api-key`.

El token se configura mediante la variable sensible de Terraform `api_token` y se inyecta como variable de entorno `API_TOKEN` en Lambda. No hardcodees tokens en el repositorio.

---

## Archivos principales del proyecto

```text
provider.tf                 → proveedor AWS
versions.tf                 → versiones requeridas de Terraform/providers
variables.tf                → variables, incluido api_token sensible
s3.tf                       → bucket S3
dynamodb.tf                 → tabla DynamoDB
iam.tf                      → rol y política IAM de Lambda
lambda.tf                   → Lambda y Lambda Function URL
cloudwatch.tf               → logs, métrica y alarma
iot.tf                      → AWS IoT Core legado/opcional
outputs.tf                  → outputs, incluido lambda_function_url
lambda/app.py               → Lambda de ingesta HTTP
scripts/post_event_test.py  → prueba HTTP desde Python local
requirements.txt            → dependencia requests para el script de prueba
```

---

## Requisitos previos

* Terraform CLI.
* AWS CLI configurado.
* Python 3.
* Credenciales AWS con permisos para gestionar los recursos del proyecto.
* Variable `TF_VAR_api_token` configurada antes de `terraform plan` y `terraform apply`.

Verificar herramientas:

```powershell
terraform -version
aws --version
python --version
aws sts get-caller-identity
```

---

## Comandos recomendados de despliegue

Desde la raíz del repositorio, en PowerShell:

```powershell
$env:TF_VAR_api_token="rapiro-demo-token-2026"

terraform fmt
terraform validate
terraform plan
terraform apply

terraform output lambda_function_url
```

> Nota: no ejecutes `terraform apply` hasta revisar el plan. La variable `api_token` es sensible; para producción usa un token distinto al ejemplo.

---

## Probar el endpoint con PowerShell

Después de aplicar Terraform, copia el output `lambda_function_url` y ejecuta:

```powershell
$URL="PEGAR_LAMBDA_FUNCTION_URL"

$payload = @{
  SessionId = "http-test-001"
  DetectedSign = "Hola"
  Confidence = 0.98
  Source = "PowerShell Test"
  DeviceId = "rapiro-lsa-thing"
  Mode = "word"
} | ConvertTo-Json

Invoke-RestMethod `
  -Uri $URL `
  -Method POST `
  -Headers @{ "x-api-key" = "rapiro-demo-token-2026" } `
  -ContentType "application/json" `
  -Body $payload
```

---

## Probar el endpoint con Python

Instalar dependencias del script local:

```powershell
python -m pip install -r requirements.txt
```

Configurar variables y enviar el evento:

```powershell
$env:RAPIRO_LAMBDA_URL="PEGAR_LAMBDA_FUNCTION_URL"
$env:RAPIRO_API_TOKEN="rapiro-demo-token-2026"
python scripts/post_event_test.py
```

El script imprime el status code y el cuerpo de respuesta devuelto por Lambda.

---

## Verificar evidencia en AWS

### DynamoDB

```powershell
aws dynamodb scan --table-name rapiro-lsa-sessions --region us-east-2
```

Buscar registros con `SessionId = http-test-001`.

### S3

```powershell
aws s3 ls s3://rapiro-lsa-models-datasets-295552411532/events/ --region us-east-2
```

Debe aparecer un JSON con un nombre similar a:

```text
events/http-test-001-1780000000.json
```

### CloudWatch Logs

```powershell
aws logs tail /aws/lambda/rapiro-lsa-inference --region us-east-2 --follow
```

Mensajes esperados:

```text
Evento recibido
Payload parseado
Evento guardado en DynamoDB
Evento guardado en S3
```

---

## Flujo legado/opcional con AWS IoT Core

El proyecto conserva recursos de AWS IoT Core para no destruir infraestructura existente:

```text
RAPIRO / Simulador MQTT → AWS IoT Core → Lambda
```

Este flujo ya no es el principal para la demo de baja latencia. Para la defensa y pruebas rápidas se recomienda usar la **Lambda Function URL** con POST HTTP.

Si `API_TOKEN` está configurado, las invocaciones directas que no incluyan header `x-api-key` serán rechazadas con HTTP 401. Esto protege el endpoint HTTP principal; si se desea reactivar IoT como flujo productivo, revisa cómo enviar o validar credenciales en ese camino legado.

---

## Validaciones locales antes de abrir PR o aplicar Terraform

```powershell
terraform fmt
terraform validate
python -m py_compile lambda/app.py
python -m py_compile scripts/post_event_test.py
terraform plan
```

No se debe ejecutar `terraform apply` automáticamente desde automatizaciones o agentes. Revisar primero el plan y confirmar manualmente.

---

## Resumen final

El repositorio deja preparada una arquitectura cloud simple y defendible:

```text
Detección local + audio local inmediato → POST HTTP en segundo plano → Lambda Function URL → DynamoDB + S3 + CloudWatch
```

Este diseño elimina a AWS del camino crítico de la voz en tiempo real, reduce latencia y mantiene evidencia cloud para monitoreo, auditoría y demostración del proyecto integrador.
