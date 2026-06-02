# cloud-rapiroLSA

Infraestructura base en AWS para RAPIRO-LSA usando Terraform. Este proyecto crea:

- Un bucket S3 privado para modelos entrenados y datasets.
- Una tabla DynamoDB para registrar historial de sesiones.
- Un rol y una política IAM para una futura función Lambda de inferencia.

> Los ejemplos usan la región `us-east-2`, que es la región configurada por defecto en este proyecto.

## Requisitos previos

Antes de ejecutar Terraform, asegúrate de tener instalado y configurado:

- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.5.0`.
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- Credenciales AWS con permisos para crear S3, DynamoDB e IAM.

Verifica tu identidad AWS:

```bash
aws sts get-caller-identity
```

Si usas un perfil específico de AWS, puedes exportarlo antes de ejecutar los comandos:

```bash
export AWS_PROFILE=mi-perfil
```

## 1. Inicializar Terraform

Desde la raíz del proyecto:

```bash
cd /workspace/cloud-rapiroLSA
terraform init
```

## 2. Revisar el plan de cambios

Genera un plan para revisar qué recursos se crearán:

```bash
terraform plan -out=tfplan
```

## 3. Aplicar el plan

Cuando hayas revisado el plan, aplícalo:

```bash
terraform apply tfplan
```

Al finalizar, Terraform debe mostrar los outputs definidos para el bucket, la tabla DynamoDB y el rol IAM.

## 4. Verificar el estado de Terraform

Lista los recursos registrados en el estado local de Terraform:

```bash
terraform state list
```

También puedes ver todos los outputs:

```bash
terraform output
```

## 5. Guardar nombres de recursos en variables de terminal

Para no copiar y pegar nombres largos, guarda los outputs de Terraform en variables de shell.

### Guardar el nombre del bucket S3

```bash
BUCKET_NAME=$(terraform output -raw s3_bucket_name)
echo "$BUCKET_NAME"
```
### Guardar el nombre de la tabla DynamoDB

```bash
TABLE_NAME=$(terraform output -raw dynamodb_table_name)
echo "$TABLE_NAME"
```

### Guardar el nombre del rol IAM de Lambda

```bash
ROLE_NAME=$(terraform output -raw lambda_inference_role_name)
echo "$ROLE_NAME"
```

> Estas variables solo existen en la terminal actual. Si abres otra terminal, vuelve a ejecutarlas.

## 6. Verificar el bucket S3

Confirma que el bucket existe y que AWS CLI puede acceder a él:

```bash
aws s3 ls "s3://$BUCKET_NAME"
```

Si el bucket está vacío, el comando puede no mostrar archivos. Lo importante es que no devuelva un error de permisos o de bucket inexistente.

También puedes revisar la ubicación del bucket:

```bash
aws s3api get-bucket-location \
  --bucket "$BUCKET_NAME"
```

## 7. Subir modelos y datasets al bucket S3

Crea carpetas locales para organizar modelos y datasets si todavía no existen:

```bash
mkdir -p models datasets
```

Sube modelos al prefijo `models/` del bucket:

```bash
aws s3 sync ./models "s3://$BUCKET_NAME/models"
```

Sube datasets al prefijo `datasets/` del bucket:

```bash
aws s3 sync ./datasets "s3://$BUCKET_NAME/datasets"
```

Verifica los archivos subidos:

```bash
aws s3 ls "s3://$BUCKET_NAME" --recursive
```

Ejemplo para subir un archivo individual:

```bash
aws s3 cp ./models/modelo-lsa.pkl "s3://$BUCKET_NAME/models/modelo-lsa.pkl"
```

## 8. Verificar la tabla DynamoDB

Describe la tabla creada por Terraform:

```bash
aws dynamodb describe-table \
  --table-name "$TABLE_NAME" \
  --region us-east-2
```

La tabla usa:

- `SessionId` como clave de partición.
- `Timestamp` como clave de ordenamiento.

## 9. Probar DynamoDB con un registro de ejemplo

Inserta un item de prueba:

```bash
aws dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --region us-east-2 \
  --item '{
    "SessionId": {"S": "test-session-001"},
    "Timestamp": {"N": "1717350000"},
    "Text": {"S": "Prueba de sesión RAPIRO-LSA"},
    "Status": {"S": "ok"}
  }'
```

Consulta el item insertado:

```bash
aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --region us-east-2 \
  --key '{
    "SessionId": {"S": "test-session-001"},
    "Timestamp": {"N": "1717350000"}
  }'
```

Si quieres eliminar el item de prueba:

```bash
aws dynamodb delete-item \
  --table-name "$TABLE_NAME" \
  --region us-east-2 \
  --key '{
    "SessionId": {"S": "test-session-001"},
    "Timestamp": {"N": "1717350000"}
  }'
```

## 10. Verificar el rol IAM de Lambda

Consulta el rol creado para la futura Lambda de inferencia:

```bash
aws iam get-role \
  --role-name "$ROLE_NAME"
```

Lista las políticas adjuntas al rol:

```bash
aws iam list-attached-role-policies \
  --role-name "$ROLE_NAME"
```

## 11. Flujo recomendado después del despliegue

Después de aplicar Terraform, el flujo sugerido es:

1. Verificar outputs y estado de Terraform.
2. Guardar `BUCKET_NAME`, `TABLE_NAME` y `ROLE_NAME` en variables de terminal.
3. Confirmar que S3, DynamoDB e IAM existen con AWS CLI.
4. Subir modelos entrenados y datasets al bucket S3.
5. Probar escritura y lectura en DynamoDB.
6. Crear o desplegar la función Lambda que usará el rol IAM generado.
7. Conectar la Lambda con el bucket, DynamoDB y otros servicios necesarios.

## 12. Limpiar recursos

Si quieres eliminar la infraestructura creada por Terraform:

```bash
terraform destroy
```

Confirma con `yes` cuando Terraform lo solicite.

> Precaución: `terraform destroy` elimina los recursos administrados por Terraform. Antes de destruir, asegúrate de respaldar modelos, datasets o datos importantes almacenados en S3 o DynamoDB.