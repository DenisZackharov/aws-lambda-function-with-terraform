output "url" {
  description = "Url for hello world" 
  value       = "${aws_api_gateway_stage.lambda.invoke_url}/${aws_api_gateway_resource.hello.path_part}"
}
