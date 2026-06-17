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

## Configuración objetivo

El despliegue esperado del repositorio es **São Paulo (`sa-east-1`)**, instancia EC2 **`t3.medium`** y sufijo de recursos **`sae1`**. Los nombres generados conservan ese sufijo para evitar recreaciones innecesarias:

| Recurso | Nombre esperado |
| --- | --- |
| EC2 backend | `rapiro-lsa-ec2-backend-sae1` |
| Security Group | `rapiro-lsa-ec2-backend-sg-sae1` |
| IAM Role | `rapiro-lsa-ec2-backend-role-sae1` |
| IAM Policy | `rapiro-lsa-ec2-backend-policy-sae1` |
| Instance Profile | `rapiro-lsa-ec2-backend-profile-sae1` |
| DynamoDB | `rapiro-lsa-sessions-sae1` |
| S3 | `rapiro-lsa-models-datasets-<account_id>-sae1` |

El provider AWS usa `var.aws_region`; no debe apuntar a otra región cuando se gestionan estos recursos. Esto evita errores de S3 como `PermanentRedirect` al administrar buckets creados en São Paulo desde un endpoint regional incorrecto.

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

Desde PowerShell, en la raíz del repo. No subas tokens reales a GitHub; pasá `api_token` como variable de entorno:

```powershell
terraform workspace new sa-east-1
# si ya existe:
terraform workspace select sa-east-1

$env:TF_VAR_aws_region="sa-east-1"
$env:TF_VAR_resource_suffix="sae1"
$env:TF_VAR_api_token="TU_TOKEN"
$env:TF_VAR_enable_ec2_backend="true"
$env:TF_VAR_instance_type="t3.medium"
# SSH queda cerrado por defecto. Preferir AWS Systems Manager Session Manager.
$env:TF_VAR_allowed_ssh_cidr=""

terraform fmt
terraform validate
terraform plan
```

En Linux/macOS, el token se pasa con `export TF_VAR_api_token="TU_TOKEN"`. Ejecutá `terraform apply` **solo manualmente** después de revisar que el plan no destruya recursos existentes. Antes de aplicar, confirmá que el plan conserve `aws_region = "sa-east-1"`, `resource_suffix = "sae1"`, `instance_type = "t3.medium"` y que no quite el sufijo `sae1` de nombres existentes. Si aun así Terraform quiere recrear recursos porque faltan en AWS, tratá eso como posible drift y revisalo antes de aplicar.

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

> **Importante:** EC2 queda encendido. `t3.medium` cuesta más que `t3.micro`; si no se está usando la demo, detener o destruir la instancia EC2 para evitar costos.

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

## Troubleshooting EC2 backend

> No ejecutes `terraform apply` durante diagnóstico si solo querés validar el repo. El flujo principal es EC2; Lambda queda como legado/opcional.

### Validación rápida desde PowerShell

```powershell
$env:AWS_PAGER=""

terraform output
terraform output -raw ec2_backend_public_ip
terraform output -raw ec2_backend_url

$EC2_IP=(terraform output -raw ec2_backend_public_ip)
$env:RAPIRO_EC2_BACKEND_URL="http://${EC2_IP}:8000"
echo $env:RAPIRO_EC2_BACKEND_URL

Test-NetConnection $EC2_IP -Port 8000

Invoke-RestMethod `
  -Uri "$env:RAPIRO_EC2_BACKEND_URL/health" `
  -Method GET
```

Si PowerShell interpreta mal la URL con `:`, armala explícitamente desde la IP pública:

```powershell
$EC2_IP=(terraform output -raw ec2_backend_public_ip)
$env:RAPIRO_EC2_BACKEND_URL="http://${EC2_IP}:8000"
echo $env:RAPIRO_EC2_BACKEND_URL
```

### Test básico local de `/health` y `/event`

```powershell
$env:RAPIRO_EC2_BACKEND_URL=(terraform output -raw ec2_backend_url)
$env:RAPIRO_API_TOKEN="rapiro-demo-token-2026"
python scripts/test_ec2_backend.py
```

El script no necesita imagen ni frame: solo prueba que FastAPI esté vivo y que `/event` registre en DynamoDB/S3.

### Estado de la instancia con AWS CLI

```powershell
$INSTANCE_ID=(terraform output -raw ec2_instance_id)

aws ec2 describe-instance-status `
  --instance-ids $INSTANCE_ID `
  --region sa-east-1 `
  --include-all-instances `
  --no-cli-pager `
  --query "InstanceStatuses[].{InstanceId:InstanceId,State:InstanceState.Name,System:SystemStatus.Status,Instance:InstanceStatus.Status}" `
  --output table
```

### Diagnóstico dentro de Session Manager

Al entrar por SSM Session Manager, copiá o ejecutá el script ya instalado por user data:

```bash
sudo bash /opt/rapiro-lsa/scripts/ec2_diagnose.sh
```

Comandos manuales equivalentes:

```bash
cat /etc/os-release
ps -p 1 -o comm=
sudo ss -tulpn | grep 8000 || true
curl -v http://localhost:8000/health || true
tail -n 100 /opt/rapiro-lsa/backend.log || true
tail -n 100 /opt/rapiro-lsa/user-data-debug.log || true
```

### Reparación rápida dentro de EC2

Si el puerto 8000 no escucha o `systemctl` no existe, levantá Uvicorn con el fallback `nohup`:

```bash
sudo bash /opt/rapiro-lsa/scripts/ec2_restart_backend.sh
```

Este script mata procesos `uvicorn main:app` anteriores, carga `/opt/rapiro-lsa/backend.env`, inicia FastAPI en `0.0.0.0:8000`, escribe logs en `/opt/rapiro-lsa/backend.log` y verifica `http://localhost:8000/health`.
