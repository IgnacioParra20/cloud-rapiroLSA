# cloud-rapiroLSA

Infraestructura cloud del proyecto integrador **RAPIRO-LSA**, implementada en **AWS** con **Terraform**. Este repositorio contiene la infraestructura, el backend FastAPI que corre en EC2 y scripts de prueba/diagnóstico para que una persona nueva pueda entender, desplegar y validar el flujo completo.

## 1. ¿Qué problema resuelve?

RAPIRO/Raspberry captura imágenes de la mano, pero no tiene recursos suficientes para ejecutar localmente OpenCV, MediaPipe y el modelo de reconocimiento de Lengua de Señas Argentina de forma continua. Por eso el procesamiento pesado se mueve a una instancia **EC2**:

1. RAPIRO/Raspberry toma un frame JPEG.
2. Lo envía al backend EC2 por HTTP.
3. EC2 decodifica la imagen, extrae keypoints de la mano y ejecuta la función de predicción.
4. El backend devuelve la seña detectada y si la predicción ya es estable.
5. Cuando la detección es estable, EC2 guarda evidencia en DynamoDB y S3.
6. RAPIRO usa la respuesta para reproducir voz localmente.

> El código actual deja listo el punto de integración `predict_sign(keypoints)` para conectar el modelo real. Si MediaPipe no está disponible, el backend mantiene `/health` y `/event` funcionando y `/frame` responde con un modo mock para pruebas básicas.

## 2. Arquitectura principal

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

## 3. Estructura del repositorio

| Ruta | Descripción |
| --- | --- |
| `versions.tf` | Define versión mínima de Terraform y provider AWS. |
| `provider.tf` | Configura el provider AWS y obtiene el `account_id`. |
| `variables.tf` | Variables de entrada: región, sufijo, token, tipo EC2, SSH, etc. |
| `locals.tf` | Nombres calculados para recursos y tags comunes. |
| `s3.tf` | Bucket privado para modelos, datasets y evidencias JSON. |
| `dynamodb.tf` | Tabla DynamoDB para historial de eventos por sesión. |
| `ec2.tf` | Instancia EC2 Ubuntu, `user_data` y configuración del backend. |
| `ec2_iam.tf` | Rol, policy e instance profile para que EC2 use AWS sin access keys. |
| `ec2_security.tf` | Security Group del backend: puerto `8000` y SSH opcional. |
| `outputs.tf` | Valores útiles después del deploy: URL, IP, bucket, tabla, instancia. |
| `ec2_user_data.sh` | Script que Terraform inyecta en EC2 para instalar y levantar la app. |
| `ec2_app/main.py` | Backend FastAPI con endpoints `/health`, `/event` y `/frame`. |
| `ec2_app/requirements.txt` | Dependencias base del backend. |
| `ec2_app/requirements-vision.txt` | Dependencias opcionales de visión como OpenCV/MediaPipe. |
| `scripts/test_ec2_backend.py` | Prueba remota de `/health` y `/event`. |
| `scripts/ec2_diagnose.sh` | Diagnóstico para correr dentro de EC2 vía SSM. |
| `scripts/ec2_restart_backend.sh` | Reinicio manual/fallback del backend dentro de EC2. |

## 4. Recursos principales en AWS

| Componente | Uso |
| --- | --- |
| EC2 | Backend principal FastAPI para recibir frames y ejecutar OpenCV/MediaPipe/modelo. |
| DynamoDB | Historial de eventos reconocidos por sesión. |
| S3 | Evidencia JSON y artefactos/datasets/modelos del proyecto. |
| IAM Instance Profile | Permisos de EC2 sin access keys dentro de la instancia. |
| Security Group | Abre `8000/tcp` para FastAPI; SSH queda cerrado salvo configuración explícita. |
| CloudWatch Agent | Envía logs básicos del backend y del bootstrap de EC2. |
| Systems Manager | Permite entrar a la instancia sin abrir SSH si la cuenta tiene SSM configurado. |

## 5. Regiones, workspaces y nombres

La región recomendada para Argentina es **São Paulo (`sa-east-1`)**. El repo usa por defecto el sufijo `sae1` para evitar mezclar recursos de distintas regiones.

| Workspace | Región | Sufijo | EC2 backend | DynamoDB | S3 |
| --- | --- | --- | --- | --- | --- |
| `default` o `sa-east-1` | `sa-east-1` | `sae1` | `rapiro-lsa-ec2-backend-sae1` | `rapiro-lsa-sessions-sae1` | `rapiro-lsa-models-datasets-<account_id>-sae1` |
| `us-east-2` opcional | `us-east-2` | vacío u otro sufijo único | `rapiro-lsa-ec2-backend` | `rapiro-lsa-sessions` | `rapiro-lsa-models-datasets-<account_id>` |

## 6. Variables importantes

| Variable | Default | Para qué sirve |
| --- | --- | --- |
| `aws_region` | `sa-east-1` | Región AWS donde se crean los recursos. |
| `resource_suffix` | `sae1` | Sufijo para diferenciar nombres por región/ambiente. |
| `api_token` | sin default | Token sensible que debe enviar RAPIRO en el header `x-api-key`. |
| `enable_ec2_backend` | `true` | Permite prender/apagar la creación de EC2. |
| `ec2_instance_type` | `t3.micro` | Tamaño de la instancia. |
| `allowed_ssh_cidr` | `""` | Si está vacío, no se abre SSH. Preferir SSM Session Manager. |
| `cloudwatch_alarm_email` | `""` | Email opcional para recibir alarmas por SNS. Si queda vacío, se crean alarmas sin notificación. |
| `cloudwatch_cpu_alarm_threshold` | `80` | Umbral de CPU alta para alarma CloudWatch. |
| `cloudwatch_memory_alarm_threshold` | `85` | Umbral de memoria alta reportada por CloudWatch Agent. |
| `cloudwatch_disk_alarm_threshold` | `85` | Umbral de disco alto reportado por CloudWatch Agent. |
| `cloudwatch_backend_error_alarm_threshold` | `1` | Cantidad de errores en 5 minutos que dispara alarma del backend. |

> No guardes tokens reales en archivos versionados ni en `*.tfvars` committeados. Usá variables de entorno `TF_VAR_*` o un mecanismo seguro de CI/CD.

## 7. Cómo funciona el backend FastAPI

La aplicación vive en `ec2_app/main.py` y expone estos endpoints:

### `GET /health`

Valida que el proceso FastAPI esté vivo. No requiere token.

Respuesta esperada:

```json
{
  "status": "ok",
  "service": "rapiro-lsa-ec2-backend"
}
```

### `POST /event`

Registra manualmente un evento reconocido. Sirve para pruebas sin cámara y requiere el header `x-api-key` si `API_TOKEN` está configurado.

Guarda:

* Un item en DynamoDB.
* Un JSON de evidencia en `s3://<bucket>/events/`.

### `POST /frame`

Recibe un frame JPEG por `multipart/form-data` con estos campos:

| Campo | Tipo | Descripción |
| --- | --- | --- |
| `SessionId` | texto | Identificador de la sesión. |
| `DeviceId` | texto | Identificador del RAPIRO/Raspberry. |
| `Mode` | texto | Modo de reconocimiento, por ejemplo `word`. |
| `frame` | archivo JPEG | Imagen comprimida enviada por la cámara. |

Flujo interno:

1. `decode_jpeg()` convierte bytes JPEG en imagen OpenCV.
2. `extract_hand_keypoints()` usa MediaPipe Hands para obtener 21 landmarks, cada uno con `x`, `y`, `z`.
3. `predict_sign(keypoints)` devuelve seña y confianza. Actualmente es el punto donde se conecta el modelo real.
4. `update_stability()` exige varias predicciones iguales antes de marcar `Stable=true`.
5. Si la seña es estable, `register_event()` guarda el evento en DynamoDB y S3.

Ejemplo de respuesta:

```json
{
  "SessionId": "session-001",
  "DetectedSign": "Hola",
  "Confidence": 0.9,
  "Stable": true,
  "Message": "Seña reconocida correctamente",
  "MediaPipeAvailable": true
}
```

## 8. Tutorial rápido para una persona nueva

### Paso 1: preparar herramientas locales

Necesitás tener instalado:

* Terraform `>= 1.5`.
* AWS CLI autenticado contra la cuenta correcta.
* Python 3 para ejecutar los scripts de prueba.
* Permisos AWS para EC2, IAM, S3, DynamoDB, CloudWatch y SSM.

Validaciones rápidas:

```bash
terraform version
aws sts get-caller-identity
python --version
```

### Paso 2: elegir región y workspace

Desde la raíz del repo:

```bash
terraform workspace new sa-east-1 || terraform workspace select sa-east-1
```

En PowerShell:

```powershell
terraform workspace new sa-east-1
# si ya existe:
terraform workspace select sa-east-1
```

### Paso 3: configurar variables sensibles y de despliegue

En bash/zsh:

```bash
export TF_VAR_aws_region="sa-east-1"
export TF_VAR_resource_suffix="sae1"
export TF_VAR_api_token="cambiar-este-token"
export TF_VAR_enable_ec2_backend="true"
export TF_VAR_ec2_instance_type="t3.micro"
export TF_VAR_allowed_ssh_cidr=""
```

En PowerShell:

```powershell
$env:TF_VAR_aws_region="sa-east-1"
$env:TF_VAR_resource_suffix="sae1"
$env:TF_VAR_api_token="cambiar-este-token"
$env:TF_VAR_enable_ec2_backend="true"
$env:TF_VAR_ec2_instance_type="t3.micro"
$env:TF_VAR_allowed_ssh_cidr=""
```

### Paso 4: validar Terraform antes de crear recursos

```bash
terraform fmt
terraform init
terraform validate
terraform plan
```

Revisá el plan antes de aplicar. Confirmá especialmente:

* Región correcta: `sa-east-1`.
* Sufijo esperado: `sae1`.
* Nombres de bucket/tabla/EC2 esperados.
* Que no haya destrucciones accidentales.

### Paso 5: aplicar manualmente

```bash
terraform apply
```

Al terminar, revisá outputs:

```bash
terraform output
terraform output -raw ec2_backend_url
terraform output -raw ec2_instance_id
```

### Paso 6: probar que el backend esté vivo

En bash/zsh:

```bash
export RAPIRO_EC2_BACKEND_URL="$(terraform output -raw ec2_backend_url)"
export RAPIRO_API_TOKEN="cambiar-este-token"
python scripts/test_ec2_backend.py
```

En PowerShell:

```powershell
$env:RAPIRO_EC2_BACKEND_URL=(terraform output -raw ec2_backend_url)
$env:RAPIRO_API_TOKEN="cambiar-este-token"
python scripts/test_ec2_backend.py
```

El script debe:

1. Consultar `GET /health`.
2. Enviar un evento manual a `POST /event`.
3. Confirmar que la respuesta incluye `event` y `s3_path`.

### Paso 7: conectar RAPIRO/Raspberry

El cliente local debe enviar cada frame al endpoint:

```text
POST http://<ip-publica-ec2>:8000/frame
Header: x-api-key: <api_token>
Content-Type: multipart/form-data
```

Campos mínimos:

```text
SessionId=session-001
DeviceId=rapiro-001
Mode=word
frame=<archivo JPEG>
```

## 9. Scripts disponibles

### `scripts/test_ec2_backend.py`

Uso principal desde tu máquina local después del deploy:

```bash
export RAPIRO_EC2_BACKEND_URL="$(terraform output -raw ec2_backend_url)"
export RAPIRO_API_TOKEN="cambiar-este-token"
python scripts/test_ec2_backend.py
```

Qué prueba:

* Que `/health` responda `status=ok`.
* Que `/event` acepte un evento con token.
* Que el backend pueda registrar en DynamoDB y S3.

Variables que usa:

| Variable | Obligatoria | Descripción |
| --- | --- | --- |
| `RAPIRO_EC2_BACKEND_URL` | sí | URL base, por ejemplo `http://1.2.3.4:8000`. |
| `RAPIRO_API_TOKEN` | no si backend no tiene token | Token enviado como `x-api-key`. |

### `scripts/ec2_diagnose.sh`

Uso dentro de EC2 por Session Manager:

```bash
sudo bash /opt/rapiro-lsa/scripts/ec2_diagnose.sh
```

Muestra:

* Fecha, usuario y sistema operativo.
* Binarios instalados (`python3`, `pip3`, `systemctl`, `journalctl`).
* Archivos instalados en `/opt/rapiro-lsa`.
* Variables de `/opt/rapiro-lsa/backend.env`.
* Puerto `8000`.
* Resultado de `/health` local.
* Últimas líneas de logs del backend y bootstrap.

### `scripts/ec2_restart_backend.sh`

Uso dentro de EC2 si el servicio no responde:

```bash
sudo bash /opt/rapiro-lsa/scripts/ec2_restart_backend.sh
```

Qué hace:

* Detiene procesos previos `uvicorn main:app`.
* Carga `/opt/rapiro-lsa/backend.env`.
* Levanta Uvicorn en `0.0.0.0:8000`.
* Escribe logs en `/opt/rapiro-lsa/backend.log`.
* Verifica `http://localhost:8000/health`.

### `ec2_user_data.sh`

No se ejecuta manualmente desde tu máquina. Terraform lo usa como plantilla en `ec2.tf` para inicializar EC2:

* Instala Python, pip, venv, curl y utilidades del sistema.
* Copia `ec2_app/main.py` y requirements a `/opt/rapiro-lsa`.
* Copia scripts de diagnóstico y reinicio.
* Crea `/opt/rapiro-lsa/backend.env` con tabla, bucket, región y token.
* Crea el virtualenv e instala dependencias.
* Configura y arranca `rapiro-lsa-backend.service` con systemd.
* Intenta instalar CloudWatch Agent sin bloquear el arranque si falla.

## 10. Monitoreo, logs y evidencia

El proyecto incluye monitoreo básico y operativo con CloudWatch:

* **CloudWatch Logs**: recibe logs del backend y del arranque de EC2.
* **CloudWatch Agent metrics**: publica métricas de memoria y disco, además de métricas de CPU recolectadas por agente.
* **CloudWatch Alarms**: alerta por status check fallido de EC2, CPU alta, memoria alta, disco alto, errores del backend y ausencia de logs recientes. El backend emite un `backend_heartbeat` cada 60 segundos para que la alarma de ausencia de logs pueda detectar caídas reales.
* **CloudWatch Dashboard**: muestra CPU/status, memoria/disco, errores, actividad del backend y consultas de logs útiles para demo/defensa.
* **SNS opcional**: si configurás `cloudwatch_alarm_email`, las alarmas envían notificaciones al email indicado. AWS enviará un correo de confirmación de suscripción que debe aceptarse.

Outputs útiles después de aplicar:

```bash
terraform output -raw cloudwatch_log_group_name
terraform output -raw cloudwatch_dashboard_name
```


### Ver eventos en DynamoDB

```bash
aws dynamodb scan \
  --table-name rapiro-lsa-sessions-sae1 \
  --region sa-east-1
```

### Ver evidencia en S3

```bash
aws s3 ls s3://rapiro-lsa-models-datasets-<account_id>-sae1/events/ --region sa-east-1
```

### Entrar por Session Manager

```bash
aws ssm start-session --target <instance-id> --region sa-east-1
```

### Ver logs dentro de EC2

```bash
sudo journalctl -u rapiro-lsa-backend.service -f
sudo tail -f /opt/rapiro-lsa/backend.log
sudo tail -f /opt/rapiro-lsa/user-data-debug.log
```

El CloudWatch Agent envía `/opt/rapiro-lsa/backend.log` y `/opt/rapiro-lsa/user-data-debug.log` al log group:

```text
/rapiro-lsa/ec2-backend/<region>
```

## 11. Seguridad

* El backend valida el header `x-api-key` contra `API_TOKEN` cuando el token está configurado.
* EC2 usa IAM Instance Profile; no necesita access keys guardadas en disco.
* El bucket S3 bloquea acceso público, usa versionado y cifrado SSE-S3.
* SSH queda cerrado por defecto con `allowed_ssh_cidr=""`.
* Para operación normal, preferir AWS Systems Manager Session Manager.

> Nota: el Security Group abre `8000/tcp` a internet para simplificar la demo. En producción convendría restringir por IP, usar HTTPS y/o poner un API Gateway/ALB con controles adicionales.

## 12. Troubleshooting común

### No responde `/health`

1. Verificá la IP y URL:

   ```bash
   terraform output -raw ec2_backend_public_ip
   terraform output -raw ec2_backend_url
   ```

2. Entrá por SSM y corré diagnóstico:

   ```bash
   aws ssm start-session --target <instance-id> --region sa-east-1
   sudo bash /opt/rapiro-lsa/scripts/ec2_diagnose.sh
   ```

3. Reiniciá el backend:

   ```bash
   sudo systemctl restart rapiro-lsa-backend.service
   sudo journalctl -u rapiro-lsa-backend.service -n 100 --no-pager
   ```

4. Si systemd no está disponible, usá el fallback:

   ```bash
   sudo bash /opt/rapiro-lsa/scripts/ec2_restart_backend.sh
   ```

### `/event` devuelve 401

El token enviado no coincide con `API_TOKEN`. Revisá:

```bash
sudo cat /opt/rapiro-lsa/backend.env
```

Y en tu máquina local:

```bash
echo "$RAPIRO_API_TOKEN"
```

### `/event` devuelve error de DynamoDB o S3

Revisá que el rol de EC2 tenga permisos y que las variables estén bien:

```bash
sudo cat /opt/rapiro-lsa/backend.env
aws sts get-caller-identity
```

### `/frame` no detecta mano

Puede pasar por:

* Frame borroso o mal iluminado.
* MediaPipe no instalado o fallando.
* Mano fuera del encuadre.
* Modelo real todavía no conectado en `predict_sign()`.

El campo `MediaPipeAvailable` de la respuesta ayuda a distinguir si el problema es de dependencias o de imagen/modelo.

## 13. Costos y apagado

> **Importante:** EC2 queda encendido y puede generar costos. Si no se está usando la demo, detener o destruir recursos.

Detener EC2 sin destruir el volumen raíz:

```bash
aws ec2 stop-instances --instance-ids <instance-id> --region sa-east-1
```

Destruir recursos administrados por Terraform en el workspace actual:

```bash
terraform destroy
```

Antes de destruir, confirmá workspace y región:

```bash
terraform workspace show
terraform output aws_region
```

## 14. Consultas útiles de CloudWatch Logs Insights

Errores recientes:

```sql
fields @timestamp, level, message, session_id, detected_sign, confidence
| filter level = "ERROR" or @message like /ERROR/
| sort @timestamp desc
| limit 20
```

Frames procesados:

```sql
fields @timestamp, session_id, device_id, detected_sign, confidence, stable, keypoints_count, mediapipe_available
| filter event = "frame_processed"
| sort @timestamp desc
| limit 50
```

Eventos registrados en DynamoDB/S3:

```sql
fields @timestamp, session_id, detected_sign, confidence, stable, s3_path
| filter event = "event_registered"
| sort @timestamp desc
| limit 50
```

## 15. Validaciones antes de subir cambios

```bash
terraform fmt -check
terraform validate
python -m py_compile ec2_app/main.py
python -m py_compile scripts/test_ec2_backend.py
```

Si cambiaste infraestructura, también corré:

```bash
terraform plan
```

No ejecutes `terraform apply` automáticamente en revisiones de código. Aplicar infraestructura debe ser una acción manual después de revisar el plan.

## 16. Explicación corta para defensa

> Se rediseñó el sistema cloud para quitar Lambda del procesamiento principal y eliminar componentes que ya no se usan. RAPIRO envía frames al backend EC2 en São Paulo, donde corre Python con FastAPI, OpenCV, MediaPipe y el modelo de reconocimiento. EC2 devuelve la seña reconocida para que RAPIRO hable localmente, y registra el evento en DynamoDB y S3 usando IAM Instance Profile, sin access keys.
