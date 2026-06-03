# Workflow recomendado

Este proyecto usa Terraform para aprovisionar AWS y una Lambda Python para procesar eventos de RAPIRO-LSA. El flujo recomendado es trabajar siempre con cambios pequeños, validar localmente y dejar que GitHub Actions repita las comprobaciones en cada Pull Request.

## 1. Preparación local

Instala las herramientas base:

- Terraform 1.5 o superior.
- AWS CLI configurado con un perfil de desarrollo.
- Python 3.11 para coincidir con el runtime de Lambda.
- `zip`, si quieres empaquetar manualmente la Lambda.

Inicializa Terraform sin aplicar cambios todavía:

```bash
terraform init
```

## 2. Ciclo de cambio seguro

Antes de abrir un Pull Request ejecuta:

```bash
terraform fmt -recursive
terraform validate
python -m py_compile lambda/app.py iot_publish_test.py
```

Luego revisa el plan contra AWS:

```bash
terraform plan -out=tfplan
```

No subas archivos `.tfstate`, planes, credenciales, certificados ni paquetes `.zip`; ya están cubiertos por `.gitignore`.

## 3. Empaquetado de Lambda

Terraform genera el ZIP de la Lambda con el provider `archive`, por lo que normalmente no necesitas crear `lambda_function.zip` a mano. Si necesitas probar el paquete manualmente puedes ejecutar:

```bash
./scripts/package_lambda.sh
```

El paquete se crea en `build/lambda_function.zip`, una carpeta generada que no debe versionarse.

## 4. GitHub Actions

El workflow `.github/workflows/terraform.yml` corre automáticamente en Pull Requests y pushes a `main` cuando cambian archivos Terraform, la Lambda o el propio workflow. Valida:

- Formato de Terraform.
- Inicialización sin backend remoto.
- `terraform validate`.
- Sintaxis Python de la Lambda y del publicador de prueba IoT.

## 5. Consejos para próximos pasos

- Configura un backend remoto de Terraform en S3 con bloqueo en DynamoDB antes de trabajar con más personas.
- Separa ambientes (`dev`, `staging`, `prod`) con workspaces o carpetas dedicadas.
- Usa variables para el topic MQTT y nombres que hoy están fijos.
- Agrega pruebas unitarias para `lambda/app.py` usando mocks de boto3.
- Considera TFLint y Checkov para encontrar problemas de calidad y seguridad de IaC.
- Activa alarmas con notificación SNS para errores de Lambda cuando la demo pase a una fase operativa.
