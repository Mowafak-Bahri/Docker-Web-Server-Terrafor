output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.web.public_dns
}

output "website_url" {
  description = "HTTP URL to access the Nginx site"
  value       = "http://${aws_instance.web.public_ip}"
}
