
provider "aws" {
  region = "us-east-1"
}

variable "region" {
  default = "us-east-1"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# S3 Static Website for Frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "frontend-${random_id.suffix.hex}"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags = {
    Name = "TaskManagerFrontend"
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = "*",
        Action = ["s3:GetObject"],
        Resource = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}

# DynamoDB Table
resource "aws_dynamodb_table" "task_manager_data" {
  name         = "task_manager_data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  tags = {
    Name = "TaskManagerData"
  }
}

# Security group for HTTP access
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "flask_server" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.allow_http.name]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y python3-pip awscli
              pip3 install flask flask-cors boto3

              mkdir -p /home/ubuntu/flask-app
              cat <<PYCODE > /home/ubuntu/flask-app/app.py
              from flask import Flask, request, jsonify
              from flask_cors import CORS
              import boto3
              import uuid
              from boto3.dynamodb.conditions import Key

              app = Flask(__name__)
              CORS(app)
              dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
              table = dynamodb.Table("task_manager_data")

              @app.route("/<path:path>", methods=["GET", "POST", "DELETE", "OPTIONS"])
              def proxy_all(path):
                  return jsonify({"message": "Proxy route: " + path}), 200

              if __name__ == "__main__":
                  app.run(host="0.0.0.0", port=80)
              PYCODE

              nohup python3 /home/ubuntu/flask-app/app.py &
              EOF

  tags = {
    Name = "FlaskTaskManager"
  }
}

# API Gateway setup
resource "aws_api_gateway_rest_api" "flask_api" {
  name        = "FlaskTaskAPI"
  description = "Proxy to Flask running on EC2"
}

resource "aws_api_gateway_resource" "any_path" {
  rest_api_id = aws_api_gateway_rest_api.flask_api.id
  parent_id   = aws_api_gateway_rest_api.flask_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "any_method" {
  rest_api_id   = aws_api_gateway_rest_api.flask_api.id
  resource_id   = aws_api_gateway_resource.any_path.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id             = aws_api_gateway_rest_api.flask_api.id
  resource_id             = aws_api_gateway_resource.any_path.id
  http_method             = aws_api_gateway_method.any_method.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_instance.flask_server.public_dns}/"
}

resource "aws_api_gateway_deployment" "flask_deployment" {
  depends_on = [aws_api_gateway_integration.proxy]
  rest_api_id = aws_api_gateway_rest_api.flask_api.id
  stage_name  = "prod"
}

output "s3_website_url" {
  value = aws_s3_bucket.frontend.website_endpoint
}

output "flask_app_ip" {
  value = aws_instance.flask_server.public_ip
}

output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.flask_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_deployment.flask_deployment.stage_name}/"
}
