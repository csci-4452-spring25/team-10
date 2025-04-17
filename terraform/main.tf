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

# DynamoDB Table for Task Storage

resource "aws_dynamodb_table" "tasks" {
  name         = "tasks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "task_id"

  attribute {
    name = "task_id"
    type = "S"
  }

  tags = {
    Name = "TaskTable"
  }
}

# EC2 Flask Backend

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

resource "aws_instance" "flask_server" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  # key_name can be added if SSH access is needed
  security_groups = [aws_security_group.allow_http.name]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y python3-pip awscli
              pip3 install flask boto3

              mkdir -p /home/ubuntu/flask-app
              cat <<EOL > /home/ubuntu/flask-app/app.py
              from flask import Flask, request, jsonify
              import boto3
              import uuid
              from datetime import datetime

              app = Flask(__name__)
              dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
              table = dynamodb.Table('tasks')

              @app.route('/tasks', methods=['POST'])
              def create_task():
                  data = request.get_json()
                  task = {
                      'task_id': str(uuid.uuid4()),
                      'title': data['title'],
                      'description': data.get('description', ''),
                      'status': 'pending',
                      'created_at': datetime.utcnow().isoformat()
                  }
                  table.put_item(Item=task)
                  return jsonify(task), 201

              @app.route('/tasks', methods=['GET'])
              def list_tasks():
                  response = table.scan()
                  return jsonify(response.get('Items', []))

              if __name__ == '__main__':
                  app.run(host='0.0.0.0', port=80)
              EOL

              nohup python3 /home/ubuntu/flask-app/app.py &
              EOF

  tags = {
    Name = "FlaskAppInstance"
  }
}

# API Gateway

resource "aws_api_gateway_rest_api" "flask_api" {
  name        = "FlaskTaskAPI"
  description = "API Gateway to forward requests to Flask app on EC2"
}

resource "aws_api_gateway_resource" "tasks" {
  rest_api_id = aws_api_gateway_rest_api.flask_api.id
  parent_id   = aws_api_gateway_rest_api.flask_api.root_resource_id
  path_part   = "tasks"
}

resource "aws_api_gateway_method" "post_tasks" {
  rest_api_id   = aws_api_gateway_rest_api.flask_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "get_tasks" {
  rest_api_id   = aws_api_gateway_rest_api.flask_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "options_tasks" {
  rest_api_id   = aws_api_gateway_rest_api.flask_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.flask_api.id
  resource_id             = aws_api_gateway_resource.tasks.id
  http_method             = aws_api_gateway_method.post_tasks.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "POST"
  uri                     = "http://${aws_instance.flask_server.public_dns}/tasks"
}

resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.flask_api.id
  resource_id             = aws_api_gateway_resource.tasks.id
  http_method             = aws_api_gateway_method.get_tasks.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "http://${aws_instance.flask_server.public_dns}/tasks"
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id             = aws_api_gateway_rest_api.flask_api.id
  resource_id             = aws_api_gateway_resource.tasks.id
  http_method             = aws_api_gateway_method.options_tasks.http_method
  type                    = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }

  integration_response {
    status_code = "200"

    response_parameters = {
      "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
      "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
      "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    }

    response_templates = {
      "application/json" = ""
    }
  }
}

resource "aws_api_gateway_method_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.flask_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = aws_api_gateway_method.options_tasks.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_deployment" "flask_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.post_integration,
    aws_api_gateway_integration.get_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.flask_api.id
  stage_name  = "prod"
}

# Outputs

output "s3_website_url" {
  value = aws_s3_bucket.frontend.website_endpoint
}

output "flask_app_ip" {
  value = aws_instance.flask_server.public_ip
}

output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.flask_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_deployment.flask_api_deployment.stage_name}/tasks"
}
