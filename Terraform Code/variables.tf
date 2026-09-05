//Declare input variable to define the primary AWS deployment region
variable "aws_region" {
  description = "Target AWS Region for multi-model router infrastructure"
  type        = string
  default     = "us-east-1"
}


//Declare input variable to define base identifier prefix for naming resources
variable "project_name" {
  description = "Prefix for all naming conventions"
  type        = string
  default     = "genai-routing"
}


//Declare input variable to define the DynamoDB audit telemetry table name
variable "dynamodb_table_name" {
  description = "Name of the DynamoDB telemetry audit ledger"
  type        = string
  default     = "genai-routing-audit"
}


//Declare input variable to specify the foundation model ID for cheap and fast inference requests
variable "fast_model_id" {
  description = "Bedrock Model ID for cheap and fast requests"
  type        = string
  default     = "amazon.nova-micro-v1:0"
}


//Declare input variable to specify the foundation model ID for complex reasoning inference requests
variable "powerful_model_id" {
  description = "Bedrock Model ID for complex and reasoning requests"
  type        = string
  default     = "amazon.nova-lite-v1:0"
}


//Declare input variable to specify the fallback foundation model ID for automatic circuit-breaker recovery
variable "fallback_model_id" {
  description = "Bedrock Model ID for circuit-breaker recovery"
  type        = string
  default     = "amazon.nova-lite-v1:0"
}