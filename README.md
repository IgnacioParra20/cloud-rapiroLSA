# cloud-rapiroLSA

Infraestructura cloud del proyecto integrador **RAPIRO-LSA**, implementada en **AWS** con **Terraform** y preparada para comparar despliegues multi-región sin destruir el entorno existente.

## Arquitectura principal actual

El rediseño prioriza baja latencia: **RAPIRO/Python detecta la seña y reproduce la voz localmente**. AWS queda fuera del camino crítico de audio y registra evidencia en segundo plano.

```text
RAPIRO / Python local
  -> detecta la seña localmente
  -> reproduce voz local inmediata
  -> envía POST HTTP en segundo plano
  -> Lambda Function URL
  -> Lambda guarda evento en DynamoDB
  -> Lambda guarda evidencia JSON en S3/events/
  -> CloudWatch registra logs y métricas
```

**AWS IoT Core se conserva como flujo legado/opcional**, pero la entrada principal para pruebas y defensa es la **Lambda Function URL**.

## Recursos por región

| Workspace | Región | Sufijo | Lambda | DynamoDB | S3 |
| --- | --- | --- | --- | --- | --- |
| `default` | `us-east-2` | vacío | `rapiro-lsa-inference` | `rapiro-lsa-sessions` | `rapiro-lsa-models-datasets-<account_id>` |
| `sa-east-1` | `sa-east-1` | `sae1` | `rapiro-lsa-inference-sae1` | `rapiro-lsa-sessions-sae1` | `rapiro-lsa-models-datasets-<account_id>-sae1` |

Los nombres se centralizan en `locals.tf`. El bucket S3 incluye el ID de cuenta y el sufijo regional para evitar conflictos globales de S3.

## Seguridad del endpoint

La Function URL usa `authorization_type = "NONE"` para permitir clientes simples, pero la Lambda valida el header `x-api-key` contra la variable sensible `api_token`. No guardes tokens reales en archivos versionados ni en `*.tfvars` committeados.

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

> El sistema fue rediseñado para reducir latencia. RAPIRO detecta y habla localmente, mientras AWS registra eventos en segundo plano. Además, se preparó la infraestructura para desplegarse en múltiples regiones. Se mantiene Ohio como entorno existente y se crea una copia en São Paulo con nombres diferenciados para comparar tiempos reales desde Argentina. La selección final de región se hace midiendo la Lambda Function URL de cada región.
