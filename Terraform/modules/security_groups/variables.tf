variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ssh_allowed_cidr" {
  type        = string
  description = "CIDR block allowed to SSH into the public EC2 instance"
}
