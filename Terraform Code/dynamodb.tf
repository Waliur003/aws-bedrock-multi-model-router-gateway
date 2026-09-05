//Declare Amazon DynamoDB table resource to store real-time invocation audit logs, token counts, and circuit-breaker telemetry
resource "aws_dynamodb_table" "audit_ledger" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"
  range_key    = "timestamp"

  # Partition Key: Unique UUID assigned to each incoming request
  attribute {
    name = "request_id"
    type = "S"
  }

  # Sort Key: Unix timestamp representing invocation execution time
  attribute {
    name = "timestamp"
    type = "N"
  }

  # Enable Point-in-Time Recovery (PITR) for enterprise data protection
  point_in_time_recovery {
    enabled = true
  }

  # Tags to identify the DynamoDB audit table resource
  tags = {
    Name = var.dynamodb_table_name
  }
}