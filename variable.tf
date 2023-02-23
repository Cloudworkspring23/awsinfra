variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}


variable "region" {
  type    = string
  default = "us-east-1"
}
variable "profile" {
  type    = string
  default = "dev"
}
data "aws_availability_zones" "available" {
  state = "available"
}
variable "subnet_private_count" {
  type    = number
  default = 3
}
variable "subnet_public_count" {
  type    = number
  default = 3
}
variable "ami_id" {
  type    = string
  default = "ami-0e14098d6744bd76f"
}
variable "sc_group" {
  type    = string
  default = "sg-091c55b62dc36eed6"
}
variable "ssh_key_name" {
  type    = string
  default = "ec2-cloud"
}