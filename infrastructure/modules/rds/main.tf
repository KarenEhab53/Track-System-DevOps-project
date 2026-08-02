# --------------------------------------------------------------------------
# RDS PostgreSQL - managed database instance for the Track System app,
# deployed into the private subnets, reachable only from EKS worker nodes
# (enforced by the security group passed in).
# --------------------------------------------------------------------------

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.name_prefix}-db-subnet-group"
  }
}

resource "random_password" "db_password" {
  length  = 20
  special = false
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.name_prefix}-postgres"
  engine                 = "postgres"
  engine_version         = var.postgres_version
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  storage_type           = "gp3"
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_security_group_id]

  multi_az                = var.multi_az
  publicly_accessible     = false
  storage_encrypted       = true
  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false # set true for real production use

  tags = {
    Name = "${var.name_prefix}-postgres"
  }
}
