variable "region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

variable "docker_image" {
  description = "Docker image to run the Flask backend"
  type        = string
  default     = "448049833584.dkr.ecr.us-east-1.amazonaws.com/task-manager-api:latest"

}
