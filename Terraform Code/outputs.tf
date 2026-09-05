//Declare output variable to expose the public HTTP API URL for invoking the multi-model router
output "api_gateway_endpoint" {
  description = "Complete invocation URL for the multi-model router"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/route"
}


//Declare output variable to expose the DynamoDB table name storing audit and telemetry items
output "dynamodb_table_name" {
  description = "Name of the DynamoDB telemetry audit ledger"
  value       = aws_dynamodb_table.audit_ledger.name
}


//Declare output variable to expose the ARN of the deployed router Lambda function
output "lambda_function_arn" {
  description = "ARN of the router Lambda function"
  value       = aws_lambda_function.router_lambda.arn
}


//Declare output variable to expose the deployed CloudWatch dashboard name for telemetry visualization
output "cloudwatch_dashboard_name" {
  description = "Name of the deployed operational dashboard"
  value       = aws_cloudwatch_dashboard.routing_dashboard.dashboard_name
}


//Declare output variable providing sample CURL command to test the cheap and fast model tier
output "curl_test_fast_tier" {
  description = "Sample CURL command to test the cheap and fast model tier"
  value       = "curl -X POST ${aws_apigatewayv2_api.http_api.api_endpoint}/route -H 'Content-Type: application/json' -d '{\"prompt\": \"What is the capital of France?\"}'"
}


//Declare output variable providing sample CURL command to test automated circuit-breaker fallback failover
output "curl_test_fallback" {
  description = "Sample CURL command to test circuit-breaker failover recovery"
  value       = "curl -X POST ${aws_apigatewayv2_api.http_api.api_endpoint}/route -H 'Content-Type: application/json' -d '{\"prompt\": \"Explain VPC Peering\", \"simulate_failure\": true}'"
}