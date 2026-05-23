variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project_name" {
  type    = string
  default = "NT548-Lab1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "availability_zone" {
  type    = string
  default = "ap-southeast-1a"
}

variable "ssh_allowed_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR allowed to SSH into the public EC2. Change to your IP (e.g. 1.2.3.4/32) for production."
}

variable "ami" {
  type        = string
  description = "AMI ID override. Leave empty to auto-resolve latest Ubuntu Server 24.04."
  default     = ""
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}
