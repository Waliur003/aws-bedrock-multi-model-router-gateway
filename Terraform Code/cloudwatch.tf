//Declare Amazon CloudWatch log group resource to store runtime execution output and standard error streams from the Lambda router
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/genai-router-lambda"
  retention_in_days = 14

  # Tags to identify the Lambda log group resource
  tags = {
    Name = "genai-router-lambda-logs"
  }
}


//Declare Amazon CloudWatch dashboard resource to visualize dynamic model invocation rates and circuit-breaker fallback counts in real time
resource "aws_cloudwatch_dashboard" "routing_dashboard" {
  dashboard_name = "GenAI-Routing-Telemetry"

  # Dashboard widget JSON body mapping metrics from the custom GenAIRouter namespace
  dashboard_body = jsonencode({
    widgets = [
      # Metric widget displaying invocations broken down by model tier
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["GenAIRouter", "ModelInvocations", "ModelId", var.fast_model_id],
            [".", ".", "ModelId", var.powerful_model_id]
          ]
          period = 60
          stat   = "Sum"
          region = var.aws_region
          title  = "Model Invocations by Tier"
        }
      },
      # Metric widget tracking automated fallback failover events
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["GenAIRouter", "FallbackCount"]
          ]
          period = 60
          stat   = "Sum"
          region = var.aws_region
          title  = "Fallback Circuit-Breaker Trigger Count"
        }
      }
    ]
  })
}