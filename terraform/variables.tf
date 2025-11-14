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
