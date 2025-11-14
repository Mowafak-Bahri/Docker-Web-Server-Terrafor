output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.webserver.public_ip
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.webserver.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = var.enable_alb ? aws_lb.web[0].dns_name : null
}

output "alb_https_url" {
  description = "HTTPS endpoint served by the Application Load Balancer"
  value       = var.enable_alb ? "https://${aws_lb.web[0].dns_name}" : null
}
