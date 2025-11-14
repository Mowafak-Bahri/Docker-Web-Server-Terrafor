variable "instance_type" {
  description = "EC2 instance type (defaults to Free Tier eligible t2.micro)"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Optional SSH key pair name (leave null to disable SSH access)"
  type        = string
  default     = null
}

variable "availability_zone" {
  description = "Availability Zone where the EC2 instance should run"
  type        = string
  default     = "ca-central-1a"
}

variable "secondary_availability_zone" {
  description = "Secondary Availability Zone used by the load balancer"
  type        = string
  default     = "ca-central-1b"
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "acm_certificate_arn" {
  description = "ARN of an ACM certificate (in the same region) for HTTPS on the Application Load Balancer"
  type        = string
}
