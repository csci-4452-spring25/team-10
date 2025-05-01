resource "aws_apigatewayv2_api" "flask_api" {
  name          = "FlaskAPIGateway"
  protocol_type = "HTTP"
}

data "aws_instance" "flask_server" {
  instance_id = aws_instance.flask_server.id
}

resource "aws_apigatewayv2_integration" "flask_integration" {
  api_id                 = aws_apigatewayv2_api.flask_api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = "http://${data.aws_instance.flask_server.public_ip}:5000"
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "proxy_route" {
  api_id    = aws_apigatewayv2_api.flask_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.flask_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.flask_api.id
  name        = "$default"
  auto_deploy = true
}

output "api_gateway_url" {
  value       = aws_apigatewayv2_stage.default.invoke_url
  description = "Public invoke URL for API Gateway"
}