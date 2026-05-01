# oidc.tf
#
# IAM OIDC provider for the EKS cluster.
# Required for IAM Roles for Service Accounts (IRSA), which lets pods
# assume IAM roles via service-account annotations — used by:
#   - AWS Load Balancer Controller
#   - EBS CSI driver
#   - External Secrets Operator
#   - Argo CD (if you give it AWS access)

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = {
    Name = "${var.project_name}-eks-oidc"
  }
}
