variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Prefix applied to resource names/tags"
  type        = string
  default     = "track-system"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "track-system-eks"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

# --- Route 53 (optional - only used if enable_route53 = true) ---
variable "enable_route53" {
  description = "Whether to create a Route 53 DNS record for the app (requires an existing hosted zone and a deployed ALB)"
  type        = bool
  default     = false
}

variable "hosted_zone_name" {
  description = "Existing public Route 53 hosted zone name, e.g. example.com"
  type        = string
  default     = ""
}

variable "record_name" {
  description = "Fully qualified record name for the app, e.g. track-system.example.com"
  type        = string
  default     = ""
}

variable "alb_dns_name" {
  description = "DNS name of the ALB created by the AWS Load Balancer Controller (fill in after first Helm deploy)"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "Hosted zone ID of the ALB (fill in after first Helm deploy)"
  type        = string
  default     = ""
}
