import json
import time
import uuid
import boto3
from botocore.exceptions import ClientError

# Initialize AWS SDK Clients
bedrock_client = boto3.client("bedrock-runtime", region_name="us-east-1")
dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
cloudwatch = boto3.client("cloudwatch", region_name="us-east-1")

TABLE_NAME = "genai-routing-audit"
table = dynamodb.Table(TABLE_NAME)

# Model Tier Definitions
MODEL_TIER_FAST = "amazon.nova-micro-v1:0"
MODEL_TIER_POWERFUL = "amazon.nova-lite-v1:0"
MODEL_TIER_FALLBACK = "amazon.nova-lite-v1:0"

COMPLEXITY_KEYWORDS = ["architect", "analyze", "evaluate", "compare", "code", "explain in detail", "optimize"]

def select_model(prompt: str, requested_tier: str = None) -> tuple[str, str]:
    """
    Evaluates prompt heuristics or user parameters to select optimal primary model.
    """
    if requested_tier == "powerful":
        return MODEL_TIER_POWERFUL, "EXPLICIT_TIER"
    if requested_tier == "fast":
        return MODEL_TIER_FAST, "EXPLICIT_TIER"

    # Heuristic 1: Prompt length analysis
    if len(prompt) > 400:
        return MODEL_TIER_POWERFUL, "HEURISTIC_PROMPT_LENGTH"

    # Heuristic 2: Keyword complexity analysis
    prompt_lower = prompt.lower()
    if any(keyword in prompt_lower for keyword in COMPLEXITY_KEYWORDS):
        return MODEL_TIER_POWERFUL, "HEURISTIC_COMPLEXITY_KEYWORD"

    return MODEL_TIER_FAST, "HEURISTIC_DEFAULT_FAST"

def call_bedrock(model_id: str, prompt: str, max_tokens: int = 300, temperature: float = 0.3):
    """
    Invokes Amazon Bedrock using the unified Converse API.
    """
    messages = [
        {
            "role": "user",
            "content": [{"text": prompt}]
        }
    ]
    
    start_time = time.time()
    response = bedrock_client.converse(
        modelId=model_id,
        messages=messages,
        inferenceConfig={
            "maxTokens": max_tokens,
            "temperature": temperature
        }
    )
    latency_ms = int((time.time() - start_time) * 1000)
    
    output_text = response["output"]["message"]["content"][0]["text"]
    usage = response.get("usage", {})
    
    return {
        "text": output_text,
        "latency_ms": latency_ms,
        "input_tokens": usage.get("inputTokens", 0),
        "output_tokens": usage.get("outputTokens", 0)
    }

def record_telemetry(request_id: str, primary_model: str, selected_model: str, routing_reason: str, 
                     fallback_used: bool, latency_ms: int, input_tokens: int, output_tokens: int, status: str):
    """
    Writes structured audit logs to DynamoDB and emits custom metrics to CloudWatch.
    """
    timestamp = int(time.time())
    
    # 1. DynamoDB Audit Entry
    table.put_item(
        Item={
            "request_id": request_id,
            "timestamp": timestamp,
            "primary_model": primary_model,
            "selected_model": selected_model,
            "routing_reason": routing_reason,
            "fallback_used": fallback_used,
            "latency_ms": latency_ms,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "status": status
        }
    )

    # 2. CloudWatch Custom Metric Publishing
    metric_data = [
        {
            "MetricName": "ModelInvocations",
            "Dimensions": [{"Name": "ModelId", "Value": selected_model}],
            "Value": 1.0,
            "Unit": "Count"
        },
        {
            "MetricName": "InvocationLatency",
            "Dimensions": [{"Name": "ModelId", "Value": selected_model}],
            "Value": float(latency_ms),
            "Unit": "Milliseconds"
        }
    ]
    
    if fallback_used:
        metric_data.append({
            "MetricName": "FallbackCount",
            "Dimensions": [{"Name": "FailedPrimary", "Value": primary_model}],
            "Value": 1.0,
            "Unit": "Count"
        })
        
    cloudwatch.put_metric_data(Namespace="GenAIRouter", MetricData=metric_data)

def lambda_handler(event, context):
    request_id = str(uuid.uuid4())
    
    # Parse Request Payload
    try:
        body = json.loads(event.get("body", "{}")) if isinstance(event.get("body"), str) else (event.get("body") or {})
    except Exception:
        body = {}
        
    prompt = body.get("prompt")
    if not prompt:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Field 'prompt' is required in JSON payload."})
        }
        
    requested_tier = body.get("tier")
    simulate_failure = body.get("simulate_failure", False)
    
    # Dynamic Model Selection
    primary_model, routing_reason = select_model(prompt, requested_tier)
    
    # Artificial failure simulation flag for verifying fallback mechanisms
    if simulate_failure:
        target_primary = "invalid-model-id-for-testing"
    else:
        target_primary = primary_model

    selected_model = target_primary
    fallback_used = False
    result_data = None
    status = "SUCCESS"

    # Execution with Circuit-Breaker Fallback
    try:
        result_data = call_bedrock(target_primary, prompt)
    except (ClientError, Exception) as primary_err:
        print(f"[WARN] Primary model {target_primary} failed: {str(primary_err)}. Triggering fallback.")
        fallback_used = True
        selected_model = MODEL_TIER_FALLBACK
        
        try:
            result_data = call_bedrock(selected_model, prompt)
        except Exception as fallback_err:
            status = "TOTAL_FAILURE"
            record_telemetry(request_id, primary_model, selected_model, routing_reason, fallback_used, 0, 0, 0, status)
            return {
                "statusCode": 502,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "Primary and fallback models both failed.", "details": str(fallback_err)})
            }

    # Record Telemetry
    record_telemetry(
        request_id=request_id,
        primary_model=primary_model,
        selected_model=selected_model,
        routing_reason=routing_reason,
        fallback_used=fallback_used,
        latency_ms=result_data["latency_ms"],
        input_tokens=result_data["input_tokens"],
        output_tokens=result_data["output_tokens"],
        status=status
    )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "status": "SUCCESS",
            "request_id": request_id,
            "routing": {
                "primary_model": primary_model,
                "selected_model": selected_model,
                "reason": routing_reason,
                "fallback_triggered": fallback_used
            },
            "telemetry": {
                "latency_ms": result_data["latency_ms"],
                "input_tokens": result_data["input_tokens"],
                "output_tokens": result_data["output_tokens"]
            },
            "completion": result_data["text"]
        })
    }