provider "aws" {
  region = "ap-southeast-2"
}

# BIẾN (VARIABLES)
variable "alert_email" {
  type        = string
  description = "Alert email address"
}

variable "target_urls" {
  type = list(string)
  default = [
    "https://www.google.com",
    "https://httpstat.us/200",
    "https://httpstat.us/503" # URL lỗi để demo
  ]
}

# DYNAMODB
resource "aws_dynamodb_table" "monitor_logs" {
  name         = "WebsiteMonitorLogs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "url"
  range_key    = "timestamp"

  attribute {
    name = "url"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }
}

# SNS TOPIC
resource "aws_sns_topic" "alert_topic" {
  name = "Website-Alert-Topic"
}
resource "aws_sns_topic_subscription" "email_target" {
  topic_arn = aws_sns_topic.alert_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# IAM
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "lambda_role" {
  name               = "LambdaMonitorRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}
resource "aws_iam_policy" "lambda_policy" {
  name = "LambdaMonitorPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = ["logs:*"], Effect = "Allow", Resource = "arn:aws:logs:*:*:*" },
      { Action = ["dynamodb:PutItem", "dynamodb:Scan", "dynamodb:Query"], Effect = "Allow", Resource = aws_dynamodb_table.monitor_logs.arn },
      { Action = "sns:Publish", Effect = "Allow", Resource = aws_sns_topic.alert_topic.arn }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# LAMBDA 1: MONITOR FUNCTION
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}
resource "aws_lambda_function" "monitor_lambda" {
  filename         = "lambda_function.zip"
  function_name    = "WebsiteMonitorFunction"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.monitor_logs.name
      SNS_TOPIC_ARN  = aws_sns_topic.alert_topic.arn
      TARGET_URLS    = jsonencode(var.target_urls)
    }
  }
}

# LAMBDA 2: API FUNCTION
data "archive_file" "api_zip" {
  type        = "zip"
  source_file = "lambda_api.py"
  output_path = "lambda_api.zip"
}
resource "aws_lambda_function" "api_lambda" {
  filename         = "lambda_api.zip"
  function_name    = "WebsiteMonitorAPIFunction"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_api.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.api_zip.output_base64sha256
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.monitor_logs.name
    }
  }
}

# EVENTBRIDGE (CRONJOB)
resource "aws_cloudwatch_event_rule" "cron" {
  name                = "every-5-minutes-monitor"
  schedule_expression = "rate(5 minutes)"
}
resource "aws_cloudwatch_event_target" "trigger" {
  rule      = aws_cloudwatch_event_rule.cron.name
  target_id = "lambda"
  arn       = aws_lambda_function.monitor_lambda.arn
}
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.monitor_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cron.arn
}

# API GATEWAY
resource "aws_api_gateway_rest_api" "api" {
  name = "WebsiteMonitorAPI"
}
resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "status"
}
resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "GET"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_lambda.invoke_arn
}
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Hỗ trợ CORS cho API Gateway
resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}
resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}
resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_integration.options_integration]
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.integration,
    aws_api_gateway_integration.options_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}

# OUTPUTS
output "api_url" {
  value = "${aws_api_gateway_deployment.deployment.invoke_url}/status"
}