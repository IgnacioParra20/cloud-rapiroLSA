# cloud-rapiroLSA

Infraestructura cloud del proyecto integrador **RAPIRO-LSA**, implementada en **AWS** con **Terraform**.

## Arquitectura principal actual

El flujo principal usa **EC2** para procesamiento continuo de frames porque RAPIRO/Raspberry no puede ejecutar MediaPipe localmente y Lambda no es adecuada para video continuo, procesos persistentes ni modelos cargados en memoria.

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
  -> CloudWatch Agent envía logs básicos del backend
```

## Recursos principales

| Componente | Uso |
| --- | --- |
| EC2 | Backend principal FastAPI para recibir frames y ejecutar OpenCV/MediaPipe/modelo. |
| DynamoDB | Historial de eventos reconocidos por sesión. |
| S3 | Evidencia JSON y artefactos/datasets/modelos del proyecto. |
| IAM Instance Profile | Permisos de EC2 sin access keys. |
| Security Group | Puerto `8000` para FastAPI; SSH cerrado salvo configuración explícita. |
| CloudWatch Agent | Envío básico de logs de la app y bootstrap. |

## Recursos por región

| Workspace | Región | Sufijo | EC2 backend | DynamoDB | S3 |
| --- | --- | --- | --- | --- | --- |
| `default` | `us-east-2` | vacío | `rapiro-lsa-ec2-backend` | `rapiro-lsa-sessions` | `rapiro-lsa-models-datasets-<account_id>` |
| `sa-east-1` | `sa-east-1` | `sae1` | `rapiro-lsa-ec2-backend-sae1` | `rapiro-lsa-sessions-sae1` | `rapiro-lsa-models-datasets-<account_id>-sae1` |

La región recomendada para Argentina es **São Paulo (`sa-east-1`)** con sufijo `sae1`.

## Seguridad del endpoint

El backend EC2 valida el header `x-api-key` contra la variable sensible `api_token`. No guardes tokens reales en archivos versionados ni en `*.tfvars` committeados.

La instancia EC2 usa IAM Instance Profile para acceder a DynamoDB, S3, CloudWatch y SSM. No se usan access keys dentro de EC2.

## Backend FastAPI

La app vive en `ec2_app/` y expone:

* `GET /health`: estado básico del servicio.
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

## Desplegar EC2 en São Paulo

Desde PowerShell, en la raíz del repo:

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

## Probar el backend EC2

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

Health directo:

```powershell
Invoke-RestMethod -Uri "$env:RAPIRO_EC2_BACKEND_URL/health" -Method GET
```

## Revisar evidencia y logs

```powershell
aws dynamodb scan --table-name rapiro-lsa-sessions-sae1 --region sa-east-1
aws s3 ls s3://rapiro-lsa-models-datasets-<account_id>-sae1/events/ --region sa-east-1
aws ssm start-session --target <instance-id> --region sa-east-1
sudo journalctl -u rapiro-lsa-backend.service -f
```

El CloudWatch Agent envía `/var/log/rapiro-lsa-backend.log` y `/var/log/rapiro-lsa-user-data.log` al log group `/rapiro-lsa/ec2-backend/<region>`.

## Costos y apagado

> **Importante:** EC2 queda encendido. Si no se está usando la demo, detener o destruir la instancia EC2 para evitar costos.

Opciones:

```powershell
# detener sin destruir datos del root volume
aws ec2 stop-instances --instance-ids <instance-id> --region sa-east-1

# destruir los recursos administrados por Terraform del workspace actual
terraform destroy
```

## Validaciones locales antes de aplicar

```powershell
terraform fmt
terraform validate
python -m py_compile ec2_app/main.py
python -m py_compile scripts/test_ec2_backend.py
terraform plan
```

No ejecutes `terraform apply` automáticamente. Primero verificá región, workspace, sufijo, nombres de recursos y ausencia de destrucciones inesperadas.

## Explicación para defensa

> Se rediseñó el sistema cloud para quitar Lambda del procesamiento principal y eliminar componentes que ya no se usan. RAPIRO envía frames al backend EC2 en São Paulo, donde corre Python con FastAPI, OpenCV, MediaPipe y el modelo de reconocimiento. EC2 devuelve la seña reconocida para que RAPIRO hable localmente, y registra el evento en DynamoDB y S3 usando IAM Instance Profile, sin access keys.
