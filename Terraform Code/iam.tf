//Declare AWS Caller Identity data source to retrieve account ID dynamically for least-privilege policy scoping
data "aws_caller_identity" "current" {}


//Declare AWS IAM role resource for the intelligent router Lambda function with trust relationship to lambda.amazonaws.com
resource "aws_iam_role" "lambda_router_role" {
  name = "GenAIRouterLambdaRole"

  # Assume role policy document establishing trust with the AWS Lambda service
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  # Tags to identify the IAM role resource
  tags = {
    Name = "GenAIRouterLambdaRole"
  }
}


//Declare AWS IAM role policy attachment to link the AWS-managed basic execution role for CloudWatch log ingestion
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_router_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


//Declare AWS IAM inline policy resource granting scoped runtime permissions to invoke Bedrock models, persist audit logs to DynamoDB, and emit custom CloudWatch metrics
resource "aws_iam_role_policy" "lambda_permissions" {
  name = "GenAIRouterExecutionPolicy"
  role = aws_iam_role.lambda_router_role.id

  # Policy document defining fine-grained runtime access
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Permission to invoke Bedrock foundation models
      {
        Sid    = "BedrockConverseInvocations"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      },
      # Permission to persist and retrieve invocation audit records in DynamoDB
      {
        Sid    = "DynamoDBAuditPersistence"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.audit_ledger.arn
      },
      # Permission to publish custom operational metrics to CloudWatch
      {
        Sid    = "CloudWatchMetricPublishing"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}