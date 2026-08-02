# --------------------------------------------------------------------------
# Root module: wires together the VPC, security groups, ECR, EKS, RDS,
# Secrets Manager, and (optionally) Route 53 modules.
# --------------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  name_prefix          = var.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix  = var.name_prefix
  cluster_name = var.cluster_name
  vpc_id       = module.vpc.vpc_id
}

module "ecr" {
  source = "./modules/ecr"

  name_prefix = var.name_prefix
}

module "rds" {
  source = "./modules/rds"

  name_prefix           = var.name_prefix
  private_subnet_ids    = module.vpc.private_subnet_ids
  rds_security_group_id = module.security_groups.rds_sg_id
}

module "secrets" {
  source = "./modules/secrets"

  name_prefix = var.name_prefix
  db_username = module.rds.username
  db_password = module.rds.password
  db_host     = module.rds.endpoint
  db_port     = module.rds.port
  db_name     = module.rds.db_name
}

module "eks" {
  source = "./modules/eks"

  name_prefix               = var.name_prefix
  cluster_name              = var.cluster_name
  private_subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids         = module.vpc.public_subnet_ids
  cluster_security_group_id = module.security_groups.eks_cluster_sg_id
  secrets_manager_arn       = module.secrets.secret_arn
}

# Optional - only create the DNS record once the app is deployed and the
# ALB's DNS name/zone id are known (set enable_route53 = true and fill in
# the alb_* variables at that point).
module "route53" {
  source = "./modules/route53"
  count  = var.enable_route53 ? 1 : 0

  hosted_zone_name = var.hosted_zone_name
  record_name      = var.record_name
  alb_dns_name     = var.alb_dns_name
  alb_zone_id      = var.alb_zone_id
}
