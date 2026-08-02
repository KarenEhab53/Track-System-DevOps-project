variable "hosted_zone_name" {
  description = "Existing Route 53 public hosted zone, e.g. example.com"
  type        = string
}

variable "record_name" {
  description = "Fully qualified record name, e.g. track-system.example.com"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB created by the AWS Load Balancer Controller"
  type        = string
}

variable "alb_zone_id" {
  description = "Hosted zone ID of the ALB"
  type        = string
}
