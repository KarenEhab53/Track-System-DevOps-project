# --------------------------------------------------------------------------
# Security groups for the EKS control plane, EKS worker nodes, and RDS.
# RDS only ever accepts traffic on 5432 from the EKS node group SG.
# --------------------------------------------------------------------------

resource "aws_security_group" "eks_cluster" {
  name        = "${var.name_prefix}-eks-cluster-sg"
  description = "Security group for the EKS control plane"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-eks-cluster-sg"
  }
}

resource "aws_security_group" "eks_nodes" {
  name        = "${var.name_prefix}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                        = "${var.name_prefix}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Nodes <-> nodes (pod-to-pod, kubelet, etc.)
resource "aws_security_group_rule" "nodes_self_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Node to node communication"
}

# Control plane -> nodes (kubelet API, webhooks)
resource "aws_security_group_rule" "control_plane_to_nodes" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  description              = "Control plane to worker kubelets"
}

# Nodes -> control plane (HTTPS API)
resource "aws_security_group_rule" "nodes_to_control_plane" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Worker nodes to control plane API"
}

# --- RDS PostgreSQL SG: 5432 restricted strictly to the EKS node group SG ---
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Security group for RDS PostgreSQL - restricted to EKS worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS worker nodes only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-rds-sg"
  }
}
