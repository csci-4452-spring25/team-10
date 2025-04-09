provider "aws" {
  region = "us-east-1"
}


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
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}

resource "random_id" "suffix" {
  byte_length = 4
}


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
  key_name      = "" #idk whos aws account we are using
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

              EOF

}
