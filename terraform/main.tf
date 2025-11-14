#######################################
# DATA SOURCES
#######################################

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in the default VPC (NEW syntax for AWS provider v6)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = [var.availability_zone]
  }
}

# Get the latest Amazon Linux 2 AMI (ALWAYS VALID)
data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  owners = ["amazon"]
}

#######################################
# SECURITY GROUP
#######################################

resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Allow inbound HTTP"
  vpc_id      = data.aws_vpc.default.id

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

#######################################
# EC2 INSTANCE
#######################################

resource "aws_instance" "webserver" {
  ami               = data.aws_ami.amazon_linux_2.id
  instance_type     = var.instance_type
  key_name          = var.key_name
  availability_zone = var.availability_zone

  subnet_id = data.aws_subnets.default.ids[0]

  vpc_security_group_ids = [
    aws_security_group.web_sg.id
  ]

  tags = {
    Name = "Docker-Web-Server"
  }

  user_data = file("${path.module}/../scripts/user_data.sh")
}
