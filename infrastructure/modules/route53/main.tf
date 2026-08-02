# --------------------------------------------------------------------------
# Route 53 DNS record mapping the app's domain name to the ALB provisioned
# by the AWS Load Balancer Controller (via the Ingress resource in the Helm
# chart). The ALB's DNS name/zone id are supplied as variables once known
# (they are outputs of the Kubernetes Ingress, fetched post-deploy - see
# README "DNS wiring" section for the exact workflow).
# --------------------------------------------------------------------------

data "aws_route53_zone" "this" {
  name         = var.hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
