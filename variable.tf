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

variable "eks_version" {
  default = "1.31"
}