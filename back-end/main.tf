terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }

  }

  required_version = "~> 1.0"

  cloud {
    organization = "techsoysauce"

    workspaces {
      name = "resume-cicd"
    }
  }

}



provider "aws" {
  region = var.aws_region
}

#test comment to trigger new GH build

# Create S3 bucket for lambda storage
resource "aws_s3_bucket" "lambda" {
  bucket = "jp-resume-lambda-s3"
}

# S3 bucket ACL
resource "aws_s3_bucket_acl" "lambda" {
  bucket = aws_s3_bucket.lambda.id
  acl    = "private"
}

# Make s3 bucket private
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.lambda.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Zip up lambda code
data "archive_file" "lambda_resume_counter" {
  type = "zip"

  source_dir  = "${path.module}/resume_visitor_counts"
  output_path = "${path.module}/resume_lambda.zip"
}

# Push zip lambda to S3
resource "aws_s3_object" "lambda_resume_counter" {
  bucket = aws_s3_bucket.lambda.id

  key    = "resume_lambda.zip"
  source = data.archive_file.lambda_resume_counter.output_path

  etag = filemd5(data.archive_file.lambda_resume_counter.output_path)
}

# Create Lambda function
resource "aws_lambda_function" "jp_resume" {
  function_name = "jp_resume_lambda"

  s3_bucket = aws_s3_bucket.lambda.id
  s3_key    = aws_s3_object.lambda_resume_counter.key

  runtime = "python3.9"
  handler = "resume-lambda.lambda_handler"

  source_code_hash = data.archive_file.lambda_resume_counter.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

# Specify cloudwatch logs for lambda
resource "aws_cloudwatch_log_group" "jp_resume" {
  name = "/aws/lambda/${aws_lambda_function.jp_resume.function_name}"

  retention_in_days = 30
}

# Create IAM role for lambda
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

# Create IAM policy to allow Lambda to access DynamoDB table
resource "aws_iam_policy" "policy" {
  name        = "jp_dynamodb_allow_lambda_policy"
  path        = "/"
  description = "Policy that allows access to DynamoDB table and cloudwatch logs"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:BatchGetItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWriteItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        "Resource" : "arn:aws:dynamodb:us-east-1:482654496154:table/jp_resume_db"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# Apply policy to IAM role
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::482654496154:policy/jp_dynamodb_allow_lambda_policy"

}

# Create API gateway
resource "aws_apigatewayv2_api" "lambda" {
  name          = "jp_resume_lambda_gw"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["http://127.0.0.1:5500", "https://www.techsoysauce.com", "https://techsoysauce.com"]
  }
}

# Create API gateway stage
resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "jp_resume_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

# API gateway integration GET
resource "aws_apigatewayv2_integration" "get" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri        = aws_lambda_function.jp_resume.invoke_arn
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# API gateway integration POST
resource "aws_apigatewayv2_integration" "post" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri        = aws_lambda_function.jp_resume.invoke_arn
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# API gateway route GET
resource "aws_apigatewayv2_route" "get" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /get_counts"
  target    = "integrations/${aws_apigatewayv2_integration.get.id}"
}

# API gateway route POST
resource "aws_apigatewayv2_route" "post" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /add_count"
  target    = "integrations/${aws_apigatewayv2_integration.post.id}"
}

# API gateway cloudwatch logs
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

# API gateway permissions to lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jp_resume.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# Build DynamoDB table 
resource "aws_dynamodb_table" "this" {
  name         = "jp_resume_db"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "record_id"
  attribute {
    name = "record_id"
    type = "S"
  }
}

# Build DynamoDB table to record site visit count
resource "aws_dynamodb_table_item" "this" {
  table_name = aws_dynamodb_table.this.name
  hash_key   = aws_dynamodb_table.this.hash_key

  item = <<ITEM
{
  "record_id": {
    "S": "0"
  },
  "record_count": {
    "N": "1"
  }
}
ITEM
}
