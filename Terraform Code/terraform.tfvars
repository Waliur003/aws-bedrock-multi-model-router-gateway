//Set regional and operational variable values for Project 5 multi-model gateway deployment
aws_region          = "us-east-1"
project_name        = "genai-routing"
dynamodb_table_name = "genai-routing-audit"
fast_model_id       = "amazon.nova-micro-v1:0"
powerful_model_id   = "amazon.nova-lite-v1:0"
fallback_model_id   = "amazon.nova-lite-v1:0"