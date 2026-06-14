# Tabla NoSQL para registrar el historial de sesiones de traducción LSA.
# PROVISIONED con 5 RCU/WCU se mantiene dentro del límite típico de Free Tier.
resource "aws_dynamodb_table" "sessions" {
  name           = local.dynamodb_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  hash_key  = "SessionId"
  range_key = "Timestamp"

  attribute {
    name = "SessionId"
    type = "S"
  }

  attribute {
    name = "Timestamp"
    type = "N"
  }
}
