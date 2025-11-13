variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "ca-central-1"
}

variable "instance_type" {
  description = "EC2 instance type for the web server"
  type        = string
  default     = "t2.micro"
}
