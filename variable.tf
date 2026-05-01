# variables.tf

variable "aws_region" {
  default = "ap-south-1"
}

variable "project_name" {
  default = "demo"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  default = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  default = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  default = "10.0.3.0/24"
}

variable "private_subnet_2_cidr" {
  default = "10.0.4.0/24"
}

variable "cluster_name" {
  default = "demo-eks-cluster"
}

# Verify the latest supported version with:
#   aws eks describe-cluster-versions --region ap-south-1
variable "eks_version" {
  default = "1.31"
}

variable "node_instance_type" {
  default = "t3.medium"
}

variable "node_desired_size" {
  default = 2
}

variable "node_min_size" {
  default = 2
}

variable "node_max_size" {
  default = 4
}

# Set to your real domain (e.g. "harbor.example.com") to enable ACM + Route 53.
# Leave empty to skip DNS/TLS provisioning for now.
variable "domain_name" {
  default = ""
}

# CIDR allowed to SSH into the bastion. CHANGE to your IP/32 before applying.
# "0.0.0.0/0" is open to the internet — only acceptable for short-lived demos.
variable "bastion_allowed_ssh_cidr" {
  default = "0.0.0.0/0"
}

variable "bastion_instance_type" {
  default = "t3.micro"
}
