terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.17"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = ">= 1.2"
}


provider "aws" {
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

resource "aws_lambda_function" "hello_world_function" {
  function_name = "helloWorld"

  role = aws_iam_role.lambda_role.arn

  filename         = data.archive_file.build_zip_file.output_path
  source_code_hash = filebase64sha256(data.archive_file.build_zip_file.output_path)

  runtime = "ruby2.7"
  handler = "index.get_hello_world"
}

resource "aws_api_gateway_rest_api" "hello_rest_gateway" {
  name = "API Gateway for lambda function"
}

resource "aws_api_gateway_resource" "hello" {
  parent_id   = aws_api_gateway_rest_api.hello_rest_gateway.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.hello_rest_gateway.id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "get_hello" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.hello.id
  rest_api_id   = aws_api_gateway_rest_api.hello_rest_gateway.id
}

resource "aws_api_gateway_integration" "hello_proxy_integration" {
  http_method             = aws_api_gateway_method.get_hello.http_method
  resource_id             = aws_api_gateway_resource.hello.id
  rest_api_id             = aws_api_gateway_rest_api.hello_rest_gateway.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello_world_function.invoke_arn
}

resource "aws_api_gateway_deployment" "hello_deployment" {
  depends_on  = [aws_api_gateway_integration.hello_proxy_integration]
  rest_api_id = aws_api_gateway_rest_api.hello_rest_gateway.id
}

resource "aws_api_gateway_stage" "hello_stage" {
  deployment_id = aws_api_gateway_deployment.hello_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.hello_rest_gateway.id
  stage_name    = "production"
}

resource "aws_lambda_permission" "hello_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.hello_rest_gateway.execution_arn}/*/*"
}
