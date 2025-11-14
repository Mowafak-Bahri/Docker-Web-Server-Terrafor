locals {
  public_subnet_map = {
    primary = {
      cidr = cidrsubnet(var.vpc_cidr, 8, 0)
      az   = var.availability_zone
    }
    secondary = {
      cidr = cidrsubnet(var.vpc_cidr, 8, 1)
      az   = var.secondary_availability_zone
    }
  }
}

#######################################
# DATA SOURCES FOR FREE-TIER MODE
#######################################

data "aws_vpc" "default" {
  default = true
}

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

data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  owners = ["amazon"]
}

#######################################
# NETWORKING (ENABLED WHEN ALB MODE)
#######################################

resource "aws_vpc" "main" {
  count = var.enable_alb ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "docker-web-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  count  = var.enable_alb ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "docker-web-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = var.enable_alb ? local.public_subnet_map : {}

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "docker-web-${each.key}"
  }
}

resource "aws_route_table" "public" {
  count  = var.enable_alb ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name = "docker-web-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = var.enable_alb ? aws_subnet.public : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

#######################################
# SECURITY GROUPS
#######################################

resource "aws_security_group" "alb" {
  count = var.enable_alb ? 1 : 0

  name        = "docker-web-alb-sg"
  description = "Allow internet traffic to ALB"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

resource "aws_security_group" "web_sg_alb" {
  count = var.enable_alb ? 1 : 0

  name        = "docker-web-instance-sg"
  description = "Allow HTTP traffic only from the ALB"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_sg_free" {
  count = var.enable_alb ? 0 : 1

  name        = "docker-web-sg"
  description = "Allow HTTP from anywhere (Free Tier mode)"
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
# APPLICATION LOAD BALANCER (OPTIONAL)
#######################################

resource "aws_lb" "web" {
  count = var.enable_alb ? 1 : 0

  name               = "docker-web-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  tags = {
    Name = "docker-web-alb"
  }
}

resource "aws_lb_target_group" "web" {
  count = var.enable_alb ? 1 : 0

  name_prefix = "dock-"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main[0].id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
    path                = "/"
  }
}

resource "aws_lb_listener" "http" {
  count = var.enable_alb ? 1 : 0

  load_balancer_arn = aws_lb.web[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  count = var.enable_alb ? 1 : 0

  load_balancer_arn = aws_lb.web[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web[0].arn
  }
}

#######################################
# EC2 INSTANCE
#######################################

resource "aws_instance" "webserver" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id = var.enable_alb ? aws_subnet.public["primary"].id : data.aws_subnets.default.ids[0]

  vpc_security_group_ids = [
    var.enable_alb ? aws_security_group.web_sg_alb[0].id : aws_security_group.web_sg_free[0].id
  ]

  associate_public_ip_address = true

  tags = {
    Name = "Docker-Web-Server"
  }

  user_data = file("${path.module}/../scripts/user_data.sh")
}

resource "aws_lb_target_group_attachment" "web" {
  count = var.enable_alb ? 1 : 0

  target_group_arn = aws_lb_target_group.web[0].arn
  target_id        = aws_instance.webserver.id
  port             = 80
}

#######################################
# MONITORING
#######################################

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "docker-web-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.webserver.id
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  count = var.enable_alb ? 1 : 0

  alarm_name          = "docker-web-alb-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = aws_lb.web[0].arn_suffix
    TargetGroup  = aws_lb_target_group.web[0].arn_suffix
  }
}
