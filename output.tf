# outputs.tf

output "vpc_id" {
  value = aws_vpc.main.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "eks_oidc_issuer_url" {
  value       = aws_eks_cluster.eks.identity[0].oidc[0].issuer
  description = "Use this when creating IRSA roles"
}

output "eks_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_ssh_command" {
  value = "ssh -i bastion-key.pem ec2-user@${aws_instance.bastion.public_ip}"
}

output "kubeconfig_command" {
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
  description = "Run this on the bastion (it's also auto-run by user_data for ec2-user)"
}

output "route53_nameservers" {
  value       = local.dns_enabled ? aws_route53_zone.main[0].name_servers : []
  description = "Delegate these NS records at your domain registrar"
}

output "acm_certificate_arn" {
  value       = local.dns_enabled ? aws_acm_certificate_validation.main[0].certificate_arn : ""
  description = "Use this in your Harbor Ingress alb.ingress.kubernetes.io/certificate-arn annotation"
}
