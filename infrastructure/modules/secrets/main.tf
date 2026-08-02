# --------------------------------------------------------------------------
# AWS Secrets Manager secret holding DB credentials. Backend EKS pods fetch
# this at runtime (via the AWS Secrets & Config Provider / External Secrets
# Operator - see helm/track-system for the Kubernetes-side wiring) instead
# of credentials ever being stored in source control or plain k8s Secrets.
# --------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.name_prefix}/db-credentials"
  description = "Track System RDS PostgreSQL credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    port     = var.db_port
    dbname   = var.db_name
  })
}
