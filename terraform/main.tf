provider "aws" {
  region = var.aws_region
}

# Data source to get the latest Amazon Linux 2 AMI in the region
data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]  # Amazon AMI owner ID (alias)
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.*-x86_64-gp2"]  # Pattern to match Amazon Linux 2 AMI
  }
}

# Security Group to allow HTTP access
resource "aws_security_group" "web_sg" {
  name        = "nginx-web-sg"
  description = "Security group for Nginx web server allowing HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]    # Open to all IPv4
    ipv6_cidr_blocks = ["::/0"]   # Open to all IPv6 (optional, for completeness)
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "nginx-web-sg"
  }
}

# Use default VPC and first default subnet for the instance
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# EC2 instance to run Docker and Nginx
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet_ids.default.ids[0]
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = file("${path.module}/../scripts/user_data.sh")  # cloud-init script to install Docker and run container

  tags = {
    Name = "nginx-docker-ec2"
  }
}
