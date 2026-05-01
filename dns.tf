# dns.tf
#
# Route 53 hosted zone + ACM certificate.
# Only created if var.domain_name is set (e.g. "harbor.example.com").
# If empty, this file is a no-op — add the domain later and re-apply.
#
# IMPORTANT: After apply, take the output `route53_nameservers` and
# delegate them at your domain registrar. The ACM cert will not validate
# until DNS is delegated.

locals {
  dns_enabled = var.domain_name != ""
  # Strip leading subdomain to get the apex zone.
  # e.g. "harbor.example.com" -> "example.com"
  # If you give just "example.com" we use it as-is.
  domain_parts    = split(".", var.domain_name)
  apex_domain     = local.dns_enabled ? join(".", slice(local.domain_parts, max(0, length(local.domain_parts) - 2), length(local.domain_parts))) : ""
}

############################
# Route 53 hosted zone
############################

resource "aws_route53_zone" "main" {
  count = local.dns_enabled ? 1 : 0
  name  = local.apex_domain

  tags = {
    Name = "${var.project_name}-zone"
  }
}

############################
# ACM certificate
############################

resource "aws_acm_certificate" "main" {
  count             = local.dns_enabled ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-cert"
  }
}

############################
# DNS records for ACM validation
############################

resource "aws_route53_record" "cert_validation" {
  for_each = local.dns_enabled ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main[0].zone_id
}

resource "aws_acm_certificate_validation" "main" {
  count                   = local.dns_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
