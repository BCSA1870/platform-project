resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"   # proves you own the domain
 
  lifecycle {
    create_before_destroy = true   # zero-downtime cert rotation
  }
 
  tags = { Name = "BCSAP1-Cert" }
}
 
# DNS records that prove you own the domain (add these to Route53 or your DNS provider)
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
 
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}
 
data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}
 
# Wait for certificate validation to complete before continuing
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
