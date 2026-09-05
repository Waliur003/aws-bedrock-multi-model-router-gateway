# AI Cloud Engineering Project 5: Resilient Multi-Model AI Router & Automatic Fallback Gateway on AWS

---

## Overview

This project implements an enterprise-grade, cost-optimized Multi-Model Generative AI Gateway using **Amazon Bedrock**, **AWS Lambda**, **Amazon API Gateway**, and **Amazon DynamoDB**.

Hardwiring applications to a single foundation model creates architectural vulnerabilities: routing basic tasks to frontier models incurs unnecessary operational costs, routing deep analysis to lightweight models produces degraded responses, and model outages or throttling (`429 ThrottlingException`) cause complete service outages.

This gateway acts as an intelligent intermediary between consumer applications and foundation model endpoints. It evaluates incoming prompt heuristics such as length, semantic keywords, and task complexity to select the optimal model tier dynamically, catches runtime execution failures automatically, and falls back to secondary models with zero downtime to the client. Every invocation is logged in a real-time DynamoDB audit table and published as custom metrics to Amazon CloudWatch.

---

## The Problem

### 1. Model Over-Provisioning & Cost Inefficiencies

Sending short classifications, simple queries, or transactional tasks to expensive models inflates inference budgets. Running lightweight models for every request, conversely, fails when deep reasoning or complex code generation is required.

### 2. The Single Point of Failure Anti-Pattern

Foundation models are subject to regional quotas, transient service degradation, and capacity bottlenecks. Without a proxy layer, downstream consumers directly face API outages whenever the chosen provider encounters service hiccups.

### 3. Lack of Telemetry & Auditing

Enterprises require continuous visibility into token usage, routing logic, execution latency, and fallback frequency to track ROI, identify failing endpoints, and optimize inference routing over time.

---

## The Solution

### Dynamic Heuristic Model Routing

Inspects incoming request payloads at runtime. Requests with complex reasoning keywords such as `evaluate`, `architect`, `analyze`, and `optimize`, or extended context windows greater than 400 characters, route directly to **Amazon Nova Lite**. Standard transactional queries route to **Amazon Nova Micro**.

### Automated Circuit-Breaker Fallback

Wraps model invocations in cross-tier exception-handling circuitry. If the primary model fails or encounters rate limits, the gateway logs the degradation and transparently re-routes the prompt to an alternate fallback model with no user-facing error.

### Comprehensive Audit Logging & Metric Emission

Persists structured records into **Amazon DynamoDB** for every transaction:

```text
request_id
primary_model
selected_model
routing_reason
fallback_used
latency_ms
token usage
```

Telemetry is also published to **Amazon CloudWatch** under the custom `GenAIRouter` namespace.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **API Gateway Ingress** | Amazon API Gateway HTTP API (`genai-routing-gw` / Route: `POST /route`) |
| **Intelligent Routing Compute** | AWS Lambda (`genai-router-lambda` / Python 3.12 / 256 MB / 30s timeout) |
| **Fast & Cheap Tier Model** | Amazon Nova Micro (`amazon.nova-micro-v1:0` via Bedrock Converse API) |
| **Reasoning Tier Model** | Amazon Nova Lite (`amazon.nova-lite-v1:0` via Bedrock Converse API) |
| **Resilient Fallback Tier Model** | Amazon Nova Lite (`amazon.nova-lite-v1:0`) |
| **Audit Ledger Database** | Amazon DynamoDB (`genai-routing-audit` / On-Demand / Point-in-Time Recovery) |
| **Observability & Custom Metrics** | Amazon CloudWatch (`GenAIRouter` Namespace: `ModelInvocations`, `FallbackCount`) |
| **Security & Permissions** | AWS IAM Least-Privilege Execution Role (`GenAIRouterLambdaRole`) |
| **Infrastructure as Code** | HashiCorp Terraform |

---

## Architecture Diagram

<img width="1169" height="1216" alt="Architecture Diagram" src="https://github.com/user-attachments/assets/d0bdad0e-a88f-4ebc-ad53-f4e955540417" />


---

## Project Procedure

### 1. Persistence Layer Setup: Amazon DynamoDB

* Created table `genai-routing-audit` with `request_id` as a String partition key and `timestamp` as a Number sort key.
* Configured on-demand scaling mode to handle variable request traffic without capacity planning.

### 2. IAM Policy Authoring & Role Provisioning

* Created `GenAIRouterLambdaRole` assuming `lambda.amazonaws.com`.
* Bound `AWSLambdaBasicExecutionRole` for CloudWatch operational logging.
* Attached an inline policy granting scoped access to:
  * `bedrock:InvokeModel`
  * DynamoDB `PutItem`
  * DynamoDB `GetItem`
  * CloudWatch `PutMetricData`

### 3. Intelligent Router Implementation

* Implemented the model selection engine in Python 3.12 using the Bedrock `converse()` API.
* Implemented parsing logic targeting prompt length, explicit tier overrides, and semantic reasoning keywords such as `evaluate`, `architect`, and `analyze`.
* Configured circuit-breaker logic catching `ClientError` to fail over to the backup model automatically.

### 4. API Ingress Provisioning: API Gateway HTTP API

* Configured `genai-routing-gw` with CORS enabled.
* Attached a `POST /route` route targeting `genai-router-lambda` via a 2.0 payload format integration.
* Applied invoke permissions allowing `apigateway.amazonaws.com` to trigger the Lambda execution environment.

### 5. Multi-Scenario Validation & Telemetry Capture

* Validated dynamic routing using simple prompts for Tier 1.
* Validated analytical prompts for Tier 2.
* Validated simulated primary failures for Tier 3 fallback.
* Verified audit entries directly within the DynamoDB console.
* Validated custom metric emission in CloudWatch.

---

## Infrastructure as Code (IaC) Architecture

The entire multi-model intelligent routing gateway infrastructure can be codified and deployed using modular HashiCorp Terraform configuration files:

```text
terraform-aws-genai-router/
├── main.tf                 # AWS provider configuration (us-east-1), archive provider, and global tags
├── variables.tf            # Parameterized inputs (region, project prefix, Bedrock model IDs, table names)
├── terraform.tfvars        # Concrete runtime values for production routing operations
├── iam.tf                  # Least-privilege IAM execution role and policy (Bedrock, DynamoDB, CloudWatch)
├── dynamodb.tf             # DynamoDB on-demand audit ledger table (genai-routing-audit)
├── lambda.tf               # Packaging (archive_file) and deployment of Python 3.12 router engine
├── api_gateway.tf          # API Gateway HTTP API, $default stage, POST /route route, and Lambda integration
├── cloudwatch.tf           # Custom CloudWatch dashboard (GenAIRouter telemetry) and log retention
└── outputs.tf              # Exported API Gateway URL, DynamoDB table, Lambda ARN, and test cURL commands
```

---

## Detailed File-by-File Technical Breakdown

### `main.tf`

Declares core Terraform requirements including the **AWS Provider** (`~> 5.0`) and **Archive Provider** (`~> 2.4`). Configures the target deployment region as **`us-east-1`** and establishes platform-wide default tags automatically inherited across all provisioned resources:

```text
Project     = "GenAI-MultiModel-Router"
Environment = "Production"
ManagedBy   = "Terraform"
```

### `variables.tf`

Declares parameterized inputs with strict typing and defaults for flexible multi-environment deployment:

```text
aws_region
project_name
dynamodb_table_name
fast_model_id
powerful_model_id
fallback_model_id
```

Default runtime values:

```text
aws_region          = "us-east-1"
project_name        = "genai-routing"
dynamodb_table_name = "genai-routing-audit"
fast_model_id       = "amazon.nova-micro-v1:0"
powerful_model_id   = "amazon.nova-lite-v1:0"
fallback_model_id   = "amazon.nova-lite-v1:0"
```

### `terraform.tfvars`

Provides explicit runtime variables decoupling environment-specific configuration from underlying logic, ensuring reproducible configurations between development and production.

### `iam.tf`

Authorizes the serverless compute execution boundary under the principle of least privilege.

#### `aws_iam_role`

Creates the Lambda execution role:

```text
GenAIRouterLambdaRole
```

The role is assumed by:

```text
lambda.amazonaws.com
```

#### Managed Policy Attachment

Attaches the AWS-managed policy:

```text
AWSLambdaBasicExecutionRole
```

This enables standard CloudWatch log streaming for the Lambda function.

#### `aws_iam_policy`

Scopes access strictly to:

```text
bedrock:InvokeModel
dynamodb:PutItem
dynamodb:GetItem
cloudwatch:PutMetricData
```

Access is limited to target Nova models, the DynamoDB audit ledger, and the custom `GenAIRouter` CloudWatch namespace.

### `dynamodb.tf`

Declares the persistent telemetry ledger:

```text
aws_dynamodb_table.genai-routing-audit
```

Configuration details:

```text
Partition Key: request_id (String)
Sort Key: timestamp (Number)
Billing Mode: PAY_PER_REQUEST
Point-in-Time Recovery: Enabled
```

This allows the audit table to absorb dynamic, spiky AI inference traffic with zero capacity planning while protecting transactional audit trails against accidental data loss.

### `lambda.tf`

Manages the serverless compute runtime and packaging.

#### `data.archive_file`

Dynamically bundles the Python router source code into a zip archive during the Terraform plan/apply cycle.

#### `aws_lambda_function`

Deploys the router function:

```text
genai-router-lambda
```

Runtime configuration:

```text
Runtime: Python 3.12
Memory: 256 MB
Timeout: 30 seconds
```

Environment variables pass active Bedrock model IDs and DynamoDB table names directly into the Lambda runtime.

### `api_gateway.tf`

Provisions the public serverless API ingress layer.

#### `aws_apigatewayv2_api`

Creates the HTTP API:

```text
genai-routing-gw
```

The API is configured with built-in CORS headers.

#### `aws_apigatewayv2_stage`

Creates the default stage:

```text
$default
```

This enables zero-latency auto-deployment.

#### `aws_apigatewayv2_route` & `aws_apigatewayv2_integration`

Directs incoming requests to the Lambda router:

```text
POST /route
Payload Format Version: 2.0
```

#### `aws_lambda_permission`

Grants explicit invoke permissions to:

```text
apigateway.amazonaws.com
```

### `cloudwatch.tf`

Establishes the observability and operational visualizer layer.

#### `aws_cloudwatch_log_group`

Enforces a 14-day log retention lifecycle on:

```text
/aws/lambda/genai-router-lambda
```

#### `aws_cloudwatch_dashboard`

Generates the operational dashboard:

```text
routing_dashboard
```

The dashboard visualizes real-time `ModelInvocations` split by `ModelId` alongside automated `FallbackCount` pulses.

### `outputs.tf`

Exposes critical platform endpoints, infrastructure IDs, and ready-to-run terminal testing commands:

```text
api_gateway_endpoint
dynamodb_table_name
lambda_function_arn
cloudwatch_dashboard_name
curl_test_fast_tier
curl_test_fallback
```

The output values support CLI validation, cross-service IAM mapping, and quick end-to-end testing of both the fast tier and automated circuit-breaker fallback path.

---

## Technical Difficulties Faced & Engineering Resolutions

### Challenge 1: Unhandled Model Failures Returning 500s to Callers

#### Root Cause Analysis

Default API calls using standard SDK wrappers bubble unhandled runtime exceptions such as `botocore.exceptions.ClientError` or validation failures directly up to API Gateway, producing generic HTTP `500 Internal Server Error` responses that interrupt client workflows.

#### Architectural Resolution

Wrapped the initial invocation within a defensive `try/except` block. Upon encountering an error from the primary endpoint, the router intercepts the failure, flags `fallback_used = True`, assigns the backup model identifier, and executes a second invocation before sending a response.

---

### Challenge 2: DynamoDB Float Precision Incompatibility

#### Root Cause Analysis

Python's standard `time.time()` outputs a floating-point number. Standard DynamoDB serialization using `boto3.resource("dynamodb")` rejects native Python `float` values, raising an `Inexact / Float not supported` serialization error.

#### Architectural Resolution

Explicitly cast UNIX timestamps and latency calculations to integers using:

```python
int(time.time())
int(latency_ms)
```

This ensured schema compliance without introducing third-party Decimal transformation layers.

---

### Challenge 3: HTTP API Gateway Wizard Route Binding Deadlock

#### Root Cause Analysis

When building HTTP APIs in the AWS Management Console, entering the route path and integration target simultaneously in the initial creation wizard occasionally stalls with:

```text
Please fill out all required fields
```

This happens due to uncommitted form state.

#### Architectural Resolution

Created the API Gateway HTTP API skeleton using the default stage, navigated to the dedicated **Routes** blade to explicitly bind `POST /route`, and linked the Lambda integration via the **Integrations** panel.

---

## Verification and Results

## Terminal Execution Output

### 1. Fast Tier Routing: `amazon.nova-micro-v1:0`

```bash
curl -X POST https://cystj3w71l.execute-api.us-east-1.amazonaws.com/route \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is the capital of France?"}'
```

```json
{
  "status": "SUCCESS",
  "request_id": "3310cf29-f241-4f93-80a3-fd4bfd3a2735",
  "routing": {
    "primary_model": "amazon.nova-micro-v1:0",
    "selected_model": "amazon.nova-micro-v1:0",
    "reason": "HEURISTIC_DEFAULT_FAST",
    "fallback_triggered": false
  },
  "telemetry": {
    "latency_ms": 751,
    "input_tokens": 7,
    "output_tokens": 92
  },
  "completion": "The capital of France is Paris..."
}
```

---

### 2. Reasoning Tier Routing: `amazon.nova-lite-v1:0`

```bash
curl -X POST https://cystj3w71l.execute-api.us-east-1.amazonaws.com/route \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Evaluate and architect a fault-tolerant multi-region database replication strategy on AWS with pros and cons."}'
```

```json
{
  "status": "SUCCESS",
  "request_id": "4182e1a9-fadd-49dc-b22a-bab1e96fa6fa",
  "routing": {
    "primary_model": "amazon.nova-lite-v1:0",
    "selected_model": "amazon.nova-lite-v1:0",
    "reason": "HEURISTIC_COMPLEXITY_KEYWORD",
    "fallback_triggered": false
  },
  "telemetry": {
    "latency_ms": 1782,
    "input_tokens": 21,
    "output_tokens": 300
  },
  "completion": "**Fault-Tolerant Multi-Region Database Replication Strategy on AWS**..."
}
```

---

### 3. Automatic Circuit-Breaker Fallback Execution

```bash
curl -X POST https://cystj3w71l.execute-api.us-east-1.amazonaws.com/route \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Explain VPC Peering", "simulate_failure": true}'
```

```json
{
  "status": "SUCCESS",
  "request_id": "372652fb-ea1b-4b8a-9a83-c442d1abd0a2",
  "routing": {
    "primary_model": "amazon.nova-micro-v1:0",
    "selected_model": "amazon.nova-lite-v1:0",
    "reason": "HEURISTIC_DEFAULT_FAST",
    "fallback_triggered": true
  },
  "telemetry": {
    "latency_ms": 2184,
    "input_tokens": 5,
    "output_tokens": 300
  },
  "completion": "VPC Peering is a networking configuration service provided by cloud providers like Amazon Web Services (AWS)..."
}
```

---

## Verification Screenshots

### 1. Terminal Routing & Fallback Verification

Displays CloudShell execution demonstrating Fast Tier routing at `751ms`, Reasoning Tier routing at `1782ms`, and automated circuit-breaker fallback failover at `2184ms`.

<img width="1862" height="657" alt="Screenshot 1" src="https://github.com/user-attachments/assets/ee0b7bc2-e4f4-4fe2-bf66-8311ac1e7b36" />

### 2. DynamoDB Audit Ledger Entries

Shows item listings inside the `genai-routing-audit` table documenting `request_id`, `primary_model`, `selected_model`, and `fallback_used` flags.

<img width="1455" height="640" alt="Screenshot 2" src="https://github.com/user-attachments/assets/c998926b-5c27-4f1d-9510-2011b116714a" />



### 3. API Gateway Route & Integration

Shows `POST /route` successfully bound to Lambda proxy integration `genai-router-lambda` with active `$default` deployment.

<img width="1579" height="699" alt="Screenshot 3" src="https://github.com/user-attachments/assets/94a8aaac-931b-4199-94c4-05069baa9646" />


### 4. CloudWatch Custom Metric Telemetry

Visualizes custom metric data in the `GenAIRouter` namespace, displaying `ModelInvocations` grouped by `ModelId` alongside `FallbackCount` anomalies.

<img width="1667" height="727" alt="Screenshot 4" src="https://github.com/user-attachments/assets/48d0e0d8-3a19-4a7f-84c6-c28c34cd16b5" />


---

## Future Improvements

### Semantic Embedding Classification

Replace regex and string heuristic matching with Amazon Titan Text Embeddings to measure semantic intent and query complexity before routing.

### Cost-Aware Predictive Routing

Read real-time pricing cards dynamically to enforce per-request cost caps, returning throttled responses or lightweight completions when budgets are reached.

### Cross-Region Fallback

Extend the circuit-breaker to fail over across AWS regions, such as `us-east-1` to `us-west-2`, to protect against broader regional service disruptions.

---

## Bottom Line

Building this multi-model routing gateway shifts the architecture from passive foundation model consumption to resilient system design. Dynamic model selection paired with automatic circuit breaking delivers high availability, optimizes cost per token, and maintains consistent response times across unpredictable enterprise workloads.
