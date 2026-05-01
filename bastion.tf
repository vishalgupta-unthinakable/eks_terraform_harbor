# bastion.tf
#
# Bastion / jump host for managing the EKS cluster.
# - SSH key generated locally and saved to bastion-key.pem
# - Public IP for SSH access (restrict via var.bastion_allowed_ssh_cidr)
# - IAM role granted EKS cluster admin via access entry
# - user_data installs aws-cli, kubectl, helm, eksctl
#
# WARNING: tls_private_key writes the private key into terraform.tfstate.
# For real production, move state to an encrypted S3 backend with KMS.

############################
# SSH key pair
############################

resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion" {
  key_name   = "${var.project_name}-bastion-key"
  public_key = tls_private_key.bastion.public_key_openssh
}

resource "local_sensitive_file" "bastion_private_key" {
  content         = tls_private_key.bastion.private_key_pem
  filename        = "${path.module}/bastion-key.pem"
  file_permission = "0600"
}

############################
# Security group
############################

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "SSH access to bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_allowed_ssh_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

############################
# IAM role for bastion
############################

resource "aws_iam_role" "bastion" {
  name = "${var.project_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Allow bastion to describe EKS clusters (needed for `aws eks update-kubeconfig`)
resource "aws_iam_role_policy" "bastion_eks_describe" {
  name = "${var.project_name}-bastion-eks-describe"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ]
      Resource = "*"
    }]
  })
}

# SSM access (so you can also use Session Manager instead of SSH)
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}-bastion-profile"
  role = aws_iam_role.bastion.name
}

############################
# AMI lookup
############################

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

############################
# user_data — install tooling
############################

locals {
  bastion_user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y git tar gzip jq unzip

    # kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl

    # helm
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # eksctl
    curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"
    tar -xzf eksctl_Linux_amd64.tar.gz -C /usr/local/bin
    rm -f eksctl_Linux_amd64.tar.gz

    # Convenience: kubeconfig for ec2-user
    sudo -u ec2-user aws eks update-kubeconfig \
      --region ${var.aws_region} \
      --name ${var.cluster_name} || true
  EOT
}

############################
# Bastion EC2
############################

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.bastion.key_name
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true

  user_data                   = local.bastion_user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

############################
# EKS access entry — grant bastion role cluster-admin
############################

resource "aws_eks_access_entry" "bastion" {
  cluster_name  = aws_eks_cluster.eks.name
  principal_arn = aws_iam_role.bastion.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = aws_eks_cluster.eks.name
  principal_arn = aws_iam_role.bastion.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}
