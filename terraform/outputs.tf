output "s3_static_website_url" {
  description = "URL of the frontend static website"
  value       = aws_s3_bucket.frontend.website_endpoint
}

output "flask_ec2_public_ip" {
  description = "Public IP of the EC2 Flask backend"
  value       = aws_instance.flask_server.public_ip
}
