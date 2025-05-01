provider "aws" {
  region = var.region
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend" {
  bucket = "frontend-${random_id.suffix.hex}"

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

  depends_on = [aws_s3_bucket.frontend]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = ["s3:GetObject"],
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}

resource "aws_dynamodb_table" "task_manager_data" {
  name         = "task-manager-data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "task_id"

  attribute {
    name = "task_id"
    type = "S"
  }

  tags = {
    Name = "TaskManagerTable"
  }
}

resource "aws_security_group" "flask_sg" {
  name        = "flask-sg"
  description = "Allow HTTP access"
  vpc_id      = "vpc-0a5949f03da954a3b"  # Replace if not using default VPC

  ingress {
    from_port   = 8080
    to_port     = 8080
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
  ami                    = "ami-0c02fb55956c7d316"  # Amazon Linux 2 (Ubuntu would need different bootstrap)
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.flask_sg.id]
  associate_public_ip_address = true

user_data = <<-EOF
  #!/bin/bash
  yum update -y
  amazon-linux-extras enable docker
  yum install -y docker awscli
  service docker start
  usermod -a -G docker ec2-user
  aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 448049833584.dkr.ecr.us-east-1.amazonaws.com
  docker run -d -p 8080:8080 --name flask-app ${var.docker_image}
EOF


  tags = {
    Name = "FlaskDockerServer"
  }
}
