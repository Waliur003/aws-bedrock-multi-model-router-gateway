//Declare Amazon API Gateway HTTP API resource to provide a serverless, low-latency REST ingress point for clients
resource "aws_apigatewayv2_api" "http_api" {
  name          = "genai-routing-gw"
  protocol_type = "HTTP"

  # Cross-Origin Resource Sharing (CORS) configuration to allow web and terminal client calls
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
  }

  # Tags to identify the HTTP API resource
  tags = {
    Name = "genai-routing-gw"
  }
}


//Declare Amazon API Gateway Stage resource configured as $default with automated deployment enabled
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  # Tags to identify the API Gateway stage resource
  tags = {
    Name = "$default"
  }
}


//Declare Amazon API Gateway integration resource to forward incoming requests directly to the Lambda router via AWS_PROXY
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.router_lambda.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}


//Declare Amazon API Gateway route resource binding the POST /route path to the Lambda proxy integration
resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /route"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}


//Declare AWS Lambda permission resource granting API Gateway execution authorization to invoke the router function
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.router_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*/route"
}