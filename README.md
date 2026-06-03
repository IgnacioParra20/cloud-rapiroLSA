# cloud-rapiroLSA

Infraestructura cloud del proyecto **RAPIRO-LSA**, implementada en **AWS** mediante **Terraform**.

Este repositorio contiene la definición de la infraestructura como código utilizada para desplegar la capa cloud del sistema. La arquitectura permite recibir eventos desde un dispositivo o simulador, procesarlos mediante AWS Lambda, registrar sesiones en DynamoDB, generar audio con Amazon Polly, almacenar archivos en S3, monitorear ejecuciones con CloudWatch y recibir mensajes mediante AWS IoT Core.

---

## Estado actual del proyecto cloud

Actualmente la demo cloud se encuentra funcional. Se implementaron y probaron los siguientes componentes:

* Amazon S3 para almacenamiento de modelos, datasets, archivos de prueba y audios generados.
* Amazon DynamoDB para registro del historial de sesiones e inferencias.
* AWS IAM para roles y políticas de permisos de Lambda.
* AWS Lambda como función principal de inferencia simulada.
* Amazon Polly para convertir texto en audio.
* Amazon CloudWatch para logs, métricas y monitoreo inicial.
* AWS IoT Core para recibir mensajes MQTT y enviarlos automáticamente a Lambda.
* Terraform como herramienta de Infraestructura como Código.
* AWS CLI para pruebas manuales desde terminal.
* GitHub como repositorio de versionado del código.

---

## Arquitectura cloud implementada

El flujo actual de la demo cloud es el siguiente:

```text
RAPIRO / Raspberry Pi / Simulador Python
        |
        | MQTT topic: rapiro/lsa/keypoints
        v
AWS IoT Core
        |
        | IoT Topic Rule
        v
AWS Lambda
        |
        ├── Registra evento en DynamoDB
        ├── Genera audio con Amazon Polly
        ├── Guarda MP3 en Amazon S3
        └── Envía logs a CloudWatch
```

El objetivo de esta arquitectura es dejar preparada la nube para recibir datos desde RAPIRO o desde una aplicación Python con MediaPipe, procesar una seña detectada y devolver una salida audible.

---

## Recursos creados en AWS

Los recursos principales creados hasta el momento son:

### Amazon S3

Bucket utilizado para almacenar modelos, datasets, archivos de prueba y audios generados por Polly.

```text
rapiro-lsa-models-datasets-295552411532
```

Uso esperado:

```text
models/      → modelos entrenados
datasets/    → datasets del proyecto
tests/       → archivos de prueba
audio/       → audios MP3 generados por Polly
```

---

### Amazon DynamoDB

Tabla utilizada para registrar sesiones, señas detectadas, niveles de confianza y marcas de tiempo.

```text
rapiro-lsa-sessions
```

Estructura de clave primaria:

```text
SessionId  → Partition Key / String
Timestamp  → Sort Key / Number
```

Ejemplo lógico de registro:

```json
{
  "SessionId": "iot-test-001",
  "Timestamp": 1717350000,
  "DetectedSign": "Hola",
  "Confidence": 0.98,
  "Source": "AWS IoT Core",
  "AudioText": "La seña detectada fue Hola."
}
```

---

### AWS IAM

Rol creado para que Lambda pueda acceder a los servicios necesarios:

```text
rapiro-lsa-lambda-inference-role
```

Política asociada:

```text
rapiro-lsa-lambda-inference-policy
```

Permisos principales:

```text
s3:GetObject
s3:PutObject
s3:ListBucket
dynamodb:PutItem
dynamodb:GetItem
dynamodb:Scan
dynamodb:Query
polly:SynthesizeSpeech
logs:CreateLogGroup
logs:CreateLogStream
logs:PutLogEvents
```

---

### AWS Lambda

Función principal de inferencia simulada:

```text
rapiro-lsa-inference
```

Responsabilidades actuales:

* Recibir un evento JSON.
* Leer datos como `SessionId`, `DetectedSign`, `Confidence` y `Source`.
* Guardar el evento en DynamoDB.
* Generar una frase de audio con Amazon Polly.
* Guardar el archivo `.mp3` en S3.
* Devolver la ruta del audio generado.
* Registrar logs en CloudWatch.

---

### Amazon Polly

Servicio utilizado para convertir el texto detectado en audio.

Ejemplo de frase generada:

```text
La seña detectada fue Hola.
```

El audio generado se almacena en S3 bajo el prefijo:

```text
audio/
```

---

### Amazon CloudWatch

Servicio utilizado para monitoreo inicial de la Lambda.

Se configuró un grupo de logs:

```text
/aws/lambda/rapiro-lsa-inference
```

También se agregó una métrica/filtro de errores y una alarma básica para detectar fallos en la Lambda.

---

### AWS IoT Core

Servicio utilizado para recibir mensajes MQTT desde RAPIRO, Raspberry Pi o un simulador Python.

Thing creado:

```text
rapiro-lsa-thing
```

Topic MQTT utilizado:

```text
rapiro/lsa/keypoints
```

Regla IoT:

```text
rapiro_lsa_rapiro_to_lambda
```

La regla escucha mensajes publicados en el topic MQTT y ejecuta automáticamente la Lambda `rapiro-lsa-inference`.

---

## Archivos principales del proyecto

```text
provider.tf       → configuración del proveedor AWS
variables.tf      → variables del proyecto
s3.tf             → definición del bucket S3
dynamodb.tf       → definición de la tabla DynamoDB
iam.tf            → rol y política IAM para Lambda
lambda.tf         → función AWS Lambda
cloudwatch.tf     → logs, métricas y alarma de CloudWatch
iot.tf            → AWS IoT Thing, política y regla MQTT
outputs.tf        → salidas importantes de Terraform
lambda/app.py     → código Python de la Lambda
lambda_function.zip → paquete ZIP desplegado en Lambda
```

---

## Requisitos previos

Antes de ejecutar Terraform, se necesita tener instalado y configurado:

* Terraform CLI.
* AWS CLI.
* Visual Studio Code o editor equivalente.
* Cuenta de AWS activa.
* Credenciales AWS configuradas localmente.
* Git para control de versiones.

Verificar instalación de Terraform:

```bash
terraform -version
```

Verificar instalación de AWS CLI:

```bash
aws --version
```

Verificar identidad AWS:

```bash
aws sts get-caller-identity
```

La región utilizada por el proyecto es:

```text
us-east-2
```

---

## Inicializar Terraform

Desde la raíz del proyecto:

```bash
terraform init
```

Este comando descarga los proveedores necesarios, como el proveedor de AWS.

---

## Validar configuración

```bash
terraform validate
```

Si la configuración es correcta, Terraform mostrará que los archivos son válidos.

---

## Formatear archivos Terraform

```bash
terraform fmt
```

Este comando ordena y formatea los archivos `.tf`.

---

## Revisar plan de cambios

```bash
terraform plan
```

También se puede guardar el plan:

```bash
terraform plan -out=tfplan
```

---

## Aplicar infraestructura

```bash
terraform apply
```

Confirmar con:

```text
yes
```

Si se usa un plan guardado:

```bash
terraform apply tfplan
```

---

## Ver outputs

```bash
terraform output
```

Outputs esperados:

```text
s3_bucket_name
s3_bucket_arn
dynamodb_table_name
dynamodb_table_arn
lambda_inference_role_name
lambda_inference_role_arn
lambda_inference_policy_arn
lambda_inference_function_name
lambda_inference_function_arn
cloudwatch_lambda_log_group
iot_thing_name
iot_topic_rule_name
iot_mqtt_topic
```

---

## Ver recursos administrados por Terraform

```bash
terraform state list
```

---

## Guardar outputs en variables de terminal

En PowerShell:

```powershell
$BUCKET_NAME = terraform output -raw s3_bucket_name
$TABLE_NAME = terraform output -raw dynamodb_table_name
$ROLE_NAME = terraform output -raw lambda_inference_role_name
```

Mostrar valores:

```powershell
echo $BUCKET_NAME
echo $TABLE_NAME
echo $ROLE_NAME
```

---

## Probar S3

Subir archivo de prueba:

```powershell
aws s3 cp .\prueba-rapiro.txt s3://rapiro-lsa-models-datasets-295552411532/tests/prueba-rapiro.txt --region us-east-2
```

Listar archivos:

```powershell
aws s3 ls s3://rapiro-lsa-models-datasets-295552411532/tests/ --region us-east-2
```

Listar todo el bucket:

```powershell
aws s3 ls s3://rapiro-lsa-models-datasets-295552411532 --recursive --region us-east-2
```

---

## Probar DynamoDB

La tabla `rapiro-lsa-sessions` usa:

```text
SessionId → String
Timestamp → Number
```

Ejemplo de `item.json`:

```json
{
  "SessionId": {
    "S": "test-session-001"
  },
  "Timestamp": {
    "N": "1717350000"
  },
  "DetectedSign": {
    "S": "Hola"
  },
  "Confidence": {
    "N": "0.94"
  },
  "Source": {
    "S": "VSCode"
  }
}
```

Insertar item:

```powershell
aws dynamodb put-item --table-name rapiro-lsa-sessions --region us-east-2 --item file://item.json
```

Ejemplo de `key.json`:

```json
{
  "SessionId": {
    "S": "test-session-001"
  },
  "Timestamp": {
    "N": "1717350000"
  }
}
```

Consultar item:

```powershell
aws dynamodb get-item --table-name rapiro-lsa-sessions --region us-east-2 --key file://key.json
```

Ver todos los registros:

```powershell
aws dynamodb scan --table-name rapiro-lsa-sessions --region us-east-2
```

---

## Empaquetar código Lambda

El código de Lambda se encuentra en:

```text
lambda/app.py
```

Cada vez que se modifica `app.py`, se debe volver a generar el ZIP:

```powershell
Compress-Archive -Path .\lambda\app.py -DestinationPath .\lambda_function.zip -Force
```

Luego se actualiza la Lambda con Terraform:

```powershell
terraform fmt
terraform validate
terraform plan
terraform apply
```

---

## Probar Lambda desde AWS CLI

Crear un archivo `payload-dynamodb.json`:

```json
{
  "SessionId": "lambda-session-001",
  "DetectedSign": "Hola",
  "Confidence": 0.94,
  "Source": "VSCode"
}
```

Invocar Lambda:

```powershell
aws lambda invoke `
  --function-name rapiro-lsa-inference `
  --region us-east-2 `
  --cli-binary-format raw-in-base64-out `
  --payload file://payload-dynamodb.json `
  response-dynamodb.json
```

Leer respuesta:

```powershell
Get-Content .\response-dynamodb.json
```

---

## Probar Amazon Polly desde AWS CLI

Generar audio directamente desde Polly:

```powershell
aws polly synthesize-speech `
  --region us-east-2 `
  --output-format mp3 `
  --voice-id Lupe `
  --text "Hola, soy RAPIRO. La seña detectada fue hola." `
  salida-rapiro.mp3
```

Si la voz `Lupe` no está disponible, probar:

```powershell
aws polly synthesize-speech `
  --region us-east-2 `
  --output-format mp3 `
  --voice-id Miguel `
  --text "Hola, soy RAPIRO LSA. Esta es una prueba de voz." `
  salida-rapiro.mp3
```

---

## Probar Lambda + Polly + S3

Crear un archivo `payload-polly.json`:

```json
{
  "SessionId": "lambda-polly-001",
  "DetectedSign": "Hola",
  "Confidence": 0.96,
  "Source": "VSCode"
}
```

Invocar Lambda:

```powershell
aws lambda invoke `
  --function-name rapiro-lsa-inference `
  --region us-east-2 `
  --cli-binary-format raw-in-base64-out `
  --payload file://payload-polly.json `
  response-polly.json
```

Leer respuesta:

```powershell
Get-Content .\response-polly.json
```

Verificar audio generado en S3:

```powershell
aws s3 ls s3://rapiro-lsa-models-datasets-295552411532/audio/ --region us-east-2
```

---

## Ver logs en CloudWatch

Listar grupos de logs:

```powershell
aws logs describe-log-groups --region us-east-2
```

El grupo de logs esperado es:

```text
/aws/lambda/rapiro-lsa-inference
```

Ver desde consola:

```text
AWS Console > CloudWatch > Logs > Log groups > /aws/lambda/rapiro-lsa-inference
```

Ahí se pueden observar:

```text
START RequestId
Evento recibido
END RequestId
REPORT RequestId
Errores de ejecución
Duración de la Lambda
```

---

## Probar AWS IoT Core desde consola

Entrar a:

```text
AWS Console > IoT Core > MQTT test client
```

Publicar en el topic:

```text
rapiro/lsa/keypoints
```

Mensaje de prueba:

```json
{
  "SessionId": "iot-final-test-001",
  "DetectedSign": "Hola",
  "Confidence": 0.98,
  "Source": "AWS IoT Core"
}
```

Presionar:

```text
Publish
```

---

## Verificar flujo completo IoT → Lambda → DynamoDB + Polly + S3

Después de publicar el mensaje MQTT, verificar:

### DynamoDB

```text
AWS Console > DynamoDB > Tables > rapiro-lsa-sessions > Explore table items
```

Buscar:

```text
SessionId = iot-final-test-001
```

### S3

```text
AWS Console > S3 > rapiro-lsa-models-datasets-295552411532 > audio/
```

Debe aparecer un archivo `.mp3` generado.

### CloudWatch

```text
AWS Console > CloudWatch > Logs > /aws/lambda/rapiro-lsa-inference
```

Debe aparecer el evento recibido desde IoT Core.

---

## Flujo de trabajo recomendado

Cada vez que se modifique infraestructura Terraform:

```powershell
terraform fmt
terraform validate
terraform plan
terraform apply
```

Cada vez que se modifique `lambda/app.py`:

```powershell
Compress-Archive -Path .\lambda\app.py -DestinationPath .\lambda_function.zip -Force
terraform plan
terraform apply
```

---

## Resumen final

La infraestructura cloud de RAPIRO-LSA ya permite demostrar un flujo completo:

```text
Mensaje MQTT → IoT Core → Lambda → DynamoDB → Polly → S3 → CloudWatch
```

Esto valida la base cloud del sistema y deja preparado el entorno para conectar la parte de visión por computadora, inteligencia artificial y RAPIRO.
