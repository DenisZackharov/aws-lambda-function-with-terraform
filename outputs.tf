output "hello_world_url" {
  description = "Url for hello world" 
  value       = "${aws_api_gateway_stage.hello_stage.invoke_url}/${aws_api_gateway_resource.hello.path_part}"
}
