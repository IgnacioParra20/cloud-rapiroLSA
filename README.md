# cloud-rapiroLSA

Infraestructura cloud del proyecto integrador **RAPIRO-LSA**, implementada en **AWS** con **Terraform** y preparada para comparar despliegues multi-región sin destruir el entorno existente.

## Arquitectura principal actual

El rediseño actual quita **AWS Lambda del flujo principal** porque el procesamiento continuo de video/frames no encaja bien con un runtime serverless stateless y con límite de tiempo. RAPIRO/Raspberry captura frames JPEG livianos y los envía a un backend **EC2 en São Paulo** que mantiene Python, FastAPI, OpenCV, MediaPipe y el modelo de IA cargados en un proceso persistente.

```text
RAPIRO / Raspberry / Python local
  -> captura frames JPEG comprimidos
  -> envía POST HTTP multipart/form-data a EC2 :8000/frame
  -> EC2 / FastAPI decodifica JPEG con OpenCV
  -> EC2 procesa mano con MediaPipe Hands
  -> EC2 ejecuta predict_sign(keypoints) / modelo IA
  -> EC2 devuelve texto reconocido, confianza y estabilidad
  -> RAPIRO reproduce voz local inmediata
  -> EC2 registra eventos estables en DynamoDB
  -> EC2 guarda evidencia JSON en S3/events/
  -> CloudWatch / journald registran logs básicos
```

**Lambda Function URL e IoT Core se conservan como flujos legado/opcionales**, pero ya no son necesarios para la demo real. La entrada recomendada es el backend EC2 FastAPI.


## Rediseño EC2 para procesamiento continuo

### Por qué EC2 reemplaza a Lambda en el camino principal

Se usa EC2 porque Lambda no es ideal para video continuo: es stateless, tiene límite de ejecución y no conviene para mantener MediaPipe/modelos cargados entre frames. EC2 mantiene un proceso Python activo, conserva estado simple por sesión y permite recibir frames continuamente desde RAPIRO/Raspberry.

La región recomendada para Argentina es **São Paulo (`sa-east-1`)** usando el sufijo `sae1`, para crear recursos como `rapiro-lsa-ec2-backend-sae1`, `rapiro-lsa-sessions-sae1` y `rapiro-lsa-models-datasets-<account_id>-sae1`.

### Backend FastAPI

La app vive en `ec2_app/` y expone:

* `GET /health`: devuelve estado básico del servicio.
* `POST /event`: registra manualmente un evento ya reconocido, útil para pruebas sin cámara.
* `POST /frame`: recibe `SessionId`, `DeviceId`, `Mode` y archivo JPEG `frame` vía `multipart/form-data`.

Ejemplo de respuesta de `/frame`:

```json
{
  "SessionId": "session-001",
  "DetectedSign": "Hola",
  "Confidence": 0.9,
  "Stable": true,
  "Message": "Seña reconocida correctamente"
}
```

La API valida el header `x-api-key` si `API_TOKEN` está definido. No uses access keys en la instancia: EC2 accede a DynamoDB, S3, CloudWatch y SSM mediante IAM Instance Profile.

### Desplegar EC2 en São Paulo

```powershell
terraform workspace new sa-east-1
# si ya existe:
terraform workspace select sa-east-1

$env:TF_VAR_aws_region="sa-east-1"
$env:TF_VAR_resource_suffix="sae1"
$env:TF_VAR_api_token="rapiro-demo-token-2026"
$env:TF_VAR_enable_ec2_backend="true"
$env:TF_VAR_ec2_instance_type="t3.micro"
# SSH queda cerrado por defecto. Preferir AWS Systems Manager Session Manager.
$env:TF_VAR_allowed_ssh_cidr=""

terraform fmt
terraform validate
terraform plan
```

Ejecutá `terraform apply` **solo manualmente** después de revisar que el plan no destruya recursos existentes.

### Probar el backend EC2

Después de aplicar manualmente:

```powershell
$env:RAPIRO_EC2_BACKEND_URL=(terraform output -raw ec2_backend_url)
$env:RAPIRO_API_TOKEN="rapiro-demo-token-2026"
python scripts/test_ec2_backend.py
```

Para probar `/frame` con una imagen JPEG local:

```powershell
python scripts/test_ec2_backend.py .\frame-test.jpg
```

También podés probar health directamente:

```powershell
Invoke-RestMethod -Uri "$env:RAPIRO_EC2_BACKEND_URL/health" -Method GET
```

### Revisar evidencia y logs

```powershell
aws dynamodb scan --table-name rapiro-lsa-sessions-sae1 --region sa-east-1
aws s3 ls s3://rapiro-lsa-models-datasets-<account_id>-sae1/events/ --region sa-east-1
aws ssm start-session --target <instance-id> --region sa-east-1
sudo journalctl -u rapiro-lsa-backend.service -f
```

### Costos y apagado

> **Importante:** EC2 queda encendido, a diferencia de Lambda. Si no se está usando la demo, detener o destruir la instancia EC2 para evitar costos.

Opciones para evitar costos:

```powershell
# detener sin destruir datos del root volume
aws ec2 stop-instances --instance-ids <instance-id> --region sa-east-1

# destruir los recursos administrados por Terraform del workspace actual
terraform destroy
```

## Recursos por región

| Workspace | Región | Sufijo | EC2 backend | Lambda legado | DynamoDB | S3 |
| --- | --- | --- | --- | --- | --- | --- |
| `default` | `us-east-2` | vacío | `rapiro-lsa-ec2-backend` | `rapiro-lsa-inference` | `rapiro-lsa-sessions` | `rapiro-lsa-models-datasets-<account_id>` |
| `sa-east-1` | `sa-east-1` | `sae1` | `rapiro-lsa-ec2-backend-sae1` | `rapiro-lsa-inference-sae1` | `rapiro-lsa-sessions-sae1` | `rapiro-lsa-models-datasets-<account_id>-sae1` |

Los nombres se centralizan en `locals.tf`. El bucket S3 incluye el ID de cuenta y el sufijo regional para evitar conflictos globales de S3.

## Seguridad del endpoint

El backend EC2 y la Function URL legada validan el header `x-api-key` contra la variable sensible `api_token`. No guardes tokens reales en archivos versionados ni en `*.tfvars` committeados.

## Desplegar/probar Ohio sin cambiar la infraestructura actual

Desde PowerShell, en la raíz del repo:

```powershell
terraform workspace select default
$env:TF_VAR_aws_region="us-east-2"
$env:TF_VAR_resource_suffix=""
$env:TF_VAR_api_token="rapiro-demo-token-2026"

terraform fmt
terraform validate
terraform plan
```

Revisá que el plan mantenga nombres sin sufijo: `rapiro-lsa-inference`, `rapiro-lsa-sessions`, `rapiro-lsa-models-datasets-<account_id>` y `/aws/lambda/rapiro-lsa-inference`.

## Crear/probar São Paulo en un workspace separado

```powershell
terraform workspace new sa-east-1
# si ya existe:
terraform workspace select sa-east-1

$env:TF_VAR_aws_region="sa-east-1"
$env:TF_VAR_resource_suffix="sae1"
$env:TF_VAR_api_token="rapiro-demo-token-2026"

terraform fmt
terraform validate
terraform plan
```

Ejecutá `terraform apply` **solo manualmente** y solo si el plan muestra recursos nuevos con sufijo `-sae1` y no intenta tocar ni destruir Ohio.

## Qué revisar en el `terraform plan` de São Paulo

* Lambda: `rapiro-lsa-inference-sae1`.
* DynamoDB: `rapiro-lsa-sessions-sae1`.
* S3: `rapiro-lsa-models-datasets-<account_id>-sae1`; nunca `rapiro-lsa-models-datasets-<account_id>` sin sufijo.
* IAM role/policy: `rapiro-lsa-lambda-inference-role-sae1` y `rapiro-lsa-lambda-inference-policy-sae1`.
* CloudWatch Logs: `/aws/lambda/rapiro-lsa-inference-sae1`.
* IoT Thing/Policy/Rule con sufijo `sae1` si se mantienen.
* Cero acciones `destroy` sobre el workspace `default`/Ohio.

## Prueba de latencia con PowerShell

Después de aplicar manualmente el workspace que quieras medir:

```powershell
$URL = terraform output -raw lambda_function_url

$payload = @{
  SessionId = "saopaulo-test-001"
  DetectedSign = "Hola"
  Confidence = 0.98
  Source = "PowerShell Sao Paulo Test"
  DeviceId = "rapiro-lsa-thing-sae1"
  Mode = "word"
} | ConvertTo-Json

$sw = [System.Diagnostics.Stopwatch]::StartNew()

$response = Invoke-RestMethod `
  -Uri $URL `
  -Method POST `
  -Headers @{ "x-api-key" = "rapiro-demo-token-2026" } `
  -ContentType "application/json" `
  -Body $payload

$sw.Stop()

$response
"Tiempo total HTTP: $($sw.ElapsedMilliseconds) ms"
```

## Prueba con Python

```powershell
python -m pip install -r requirements.txt
$env:RAPIRO_LAMBDA_URL=(terraform output -raw lambda_function_url)
$env:RAPIRO_API_TOKEN="rapiro-demo-token-2026"
python scripts/post_event_test.py
```

El script solo depende de `RAPIRO_LAMBDA_URL` y `RAPIRO_API_TOKEN`, por lo que sirve para Ohio o São Paulo cambiando esas variables.

## Verificación de evidencia

Para Ohio:

```powershell
aws dynamodb scan --table-name rapiro-lsa-sessions --region us-east-2
aws s3 ls s3://rapiro-lsa-models-datasets-<account_id>/events/ --region us-east-2
aws logs tail /aws/lambda/rapiro-lsa-inference --region us-east-2 --follow
```

Para São Paulo:

```powershell
aws dynamodb scan --table-name rapiro-lsa-sessions-sae1 --region sa-east-1
aws s3 ls s3://rapiro-lsa-models-datasets-<account_id>-sae1/events/ --region sa-east-1
aws logs tail /aws/lambda/rapiro-lsa-inference-sae1 --region sa-east-1 --follow
```

## Validaciones locales antes de aplicar

```powershell
terraform fmt
terraform validate
python -m py_compile lambda/app.py
python -m py_compile scripts/post_event_test.py
terraform plan
```

No ejecutes `terraform apply` automáticamente. Primero verificá región, workspace, sufijo, nombres de recursos y ausencia de destrucciones inesperadas.

## Explicación para defensa

> Se rediseñó el sistema cloud para quitar Lambda del procesamiento principal, porque Lambda no es adecuada para video continuo. RAPIRO envía frames al backend EC2 en São Paulo, donde corre Python con FastAPI, OpenCV, MediaPipe y el modelo de reconocimiento. EC2 devuelve la seña reconocida para que RAPIRO hable localmente, y registra el evento en DynamoDB y S3. Lambda queda como componente legado/opcional, mientras EC2 se convierte en el backend cloud principal para procesamiento continuo.
