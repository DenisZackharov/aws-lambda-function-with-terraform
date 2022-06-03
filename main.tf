terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

data "archive_file" "build_zip_file" {
  type = "zip"

  source_dir  = "${path.module}/hello_world"
  output_path = "${path.module}/hello_world.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "iam_for_lambda_function"

  assume_role_policy = jsonencode(
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "lambda.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
  )
}

resource "aws_lambda_function" "hello" {
  function_name = "helloWorld"

  role = aws_iam_role.lambda_role.arn

  filename         = data.archive_file.build_zip_file.output_path
  source_code_hash = filebase64sha256(data.archive_file.build_zip_file.output_path)

  runtime = "ruby2.7"
  handler = "index.get_hello_world"
}

resource "aws_api_gateway_rest_api" "lambda" {
  name = "gateway for lambda function"
}

resource "aws_api_gateway_resource" "hello" {
  parent_id   = aws_api_gateway_rest_api.lambda.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.lambda.id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "hello" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.hello.id
  rest_api_id   = aws_api_gateway_rest_api.lambda.id
}

resource "aws_api_gateway_integration" "lambda" {
  http_method             = aws_api_gateway_method.hello.http_method
  resource_id             = aws_api_gateway_resource.hello.id
  rest_api_id             = aws_api_gateway_rest_api.lambda.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello.invoke_arn
}

resource "aws_api_gateway_deployment" "lambda" {
  depends_on  = [aws_api_gateway_integration.lambda]
  rest_api_id = aws_api_gateway_rest_api.lambda.id
}

resource "aws_api_gateway_stage" "lambda" {
  deployment_id = aws_api_gateway_deployment.lambda.id
  rest_api_id   = aws_api_gateway_rest_api.lambda.id
  stage_name    = "production"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.lambda.execution_arn}/*/*"
}
