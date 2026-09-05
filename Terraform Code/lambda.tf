//Declare archive file data source to package the Python routing engine into a deployment zip archive
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/router_payload.zip"

  # Source code file containing the router heuristic and circuit-breaker implementation
  source {
    content  = file("${path.module}/lambda_function.py")
    filename = "lambda_function.py"
  }
}


//Declare AWS Lambda function resource running Python 3.12 to perform heuristic prompt evaluation, model routing, and automatic fallback failover
resource "aws_lambda_function" "router_lambda" {
  function_name    = "genai-router-lambda"
  role             = aws_iam_role.lambda_router_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  # Zip archive references and SHA256 checksum tracking for zero-downtime updates
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Runtime environment variables injected into the execution container
  environment {
    variables = {
      AWS_REGION        = var.aws_region
      TABLE_NAME        = aws_dynamodb_table.audit_ledger.name
      FAST_MODEL_ID     = var.fast_model_id
      POWERFUL_MODEL_ID = var.powerful_model_id
      FALLBACK_MODEL_ID = var.fallback_model_id
    }
  }

  # Explicit dependency declarations ensuring log groups and policies exist prior to function initialization
  depends_on = [
    aws_iam_role_policy.lambda_permissions,
    aws_cloudwatch_log_group.lambda_logs
  ]

  # Tags to identify the Lambda router resource
  tags = {
    Name = "genai-router-lambda"
  }
}