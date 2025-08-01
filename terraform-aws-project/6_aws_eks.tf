# EKS Clusters (equivalent to GKE clusters)

# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster" {
  for_each = local.eks_clusters
  name     = "eks-cluster-role-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "eks-cluster-role-${each.key}"
    Cluster = each.value.cluster_name
  }
}

# Attach policies to EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  for_each   = local.eks_clusters
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster[each.key].name
}

# EKS Node Group IAM Role
resource "aws_iam_role" "eks_node_group" {
  for_each = local.eks_clusters
  name     = "eks-node-group-role-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "eks-node-group-role-${each.key}"
    Cluster = each.value.cluster_name
  }
}

# Attach policies to EKS node group role
resource "aws_iam_role_policy_attachment" "eks_node_group_worker" {
  for_each   = local.eks_clusters
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group[each.key].name
}

resource "aws_iam_role_policy_attachment" "eks_node_group_cni" {
  for_each   = local.eks_clusters
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group[each.key].name
}

resource "aws_iam_role_policy_attachment" "eks_node_group_registry" {
  for_each   = local.eks_clusters
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group[each.key].name
}

# Security group for EKS clusters
resource "aws_security_group" "eks_cluster" {
  for_each    = local.eks_clusters
  name        = "sg-eks-cluster-${each.key}"
  description = "Security group for EKS cluster ${each.value.cluster_name}"
  vpc_id      = aws_vpc.main[each.value.vpc_name].id

  # Allow HTTPS traffic from anywhere (for API server)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic within VPC
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [local.networks[each.value.vpc_name].vpc_cidr]
  }

  # Allow all traffic between VPCs
  dynamic "ingress" {
    for_each = local.networks
    content {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = [ingress.value.vpc_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "sg-eks-cluster-${each.key}"
    Cluster = each.value.cluster_name
    VPC     = each.value.vpc_name
  }
}

# Security group for EKS nodes
resource "aws_security_group" "eks_nodes" {
  for_each    = local.eks_clusters
  name        = "sg-eks-nodes-${each.key}"
  description = "Security group for EKS nodes ${each.value.cluster_name}"
  vpc_id      = aws_vpc.main[each.value.vpc_name].id

  # Allow nodes to communicate with each other
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  # Allow nodes to receive communication from cluster
  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster[each.key].id]
  }

  # Allow HTTPS communication from cluster
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster[each.key].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "sg-eks-nodes-${each.key}"
    Cluster = each.value.cluster_name
    VPC     = each.value.vpc_name
  }
}

# EKS Clusters
resource "aws_eks_cluster" "main" {
  for_each = local.eks_clusters
  name     = each.value.cluster_name
  role_arn = aws_iam_role.eks_cluster[each.key].arn
  version  = "1.27"

  vpc_config {
    subnet_ids = [
      for subnet in aws_subnet.private : subnet.id 
      if subnet.tags.VPC == each.value.vpc_name
    ]
    security_group_ids      = [aws_security_group.eks_cluster[each.key].id]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  # Enable EKS cluster logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Encryption configuration
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks[each.key].arn
    }
    resources = ["secrets"]
  }

  tags = {
    Name        = each.value.cluster_name
    Cluster     = each.key
    VPC         = each.value.vpc_name
    Environment = local.accounts[split("_", each.key)[0]].environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_cloudwatch_log_group.eks_cluster
  ]
}

# KMS key for EKS encryption
resource "aws_kms_key" "eks" {
  for_each    = local.eks_clusters
  description = "KMS key for EKS cluster ${each.value.cluster_name}"

  tags = {
    Name    = "kms-eks-${each.key}"
    Cluster = each.value.cluster_name
  }
}

resource "aws_kms_alias" "eks" {
  for_each      = local.eks_clusters
  name          = "alias/eks-${each.key}"
  target_key_id = aws_kms_key.eks[each.key].key_id
}

# CloudWatch log group for EKS
resource "aws_cloudwatch_log_group" "eks_cluster" {
  for_each          = local.eks_clusters
  name              = "/aws/eks/${each.value.cluster_name}/cluster"
  retention_in_days = 30

  tags = {
    Name    = "eks-log-group-${each.key}"
    Cluster = each.value.cluster_name
  }
}

# EKS Node Groups
resource "aws_eks_node_group" "main" {
  for_each = {
    for combo in flatten([
      for cluster_key, cluster_config in local.eks_clusters : [
        for ng_key, ng_config in cluster_config.node_groups : {
          cluster_key = cluster_key
          ng_key      = ng_key
          cluster_config = cluster_config
          ng_config   = ng_config
        }
      ]
    ]) : "${combo.cluster_key}-${combo.ng_key}" => combo
  }

  cluster_name    = aws_eks_cluster.main[each.value.cluster_key].name
  node_group_name = "${each.value.cluster_config.cluster_name}-${each.value.ng_key}"
  node_role_arn   = aws_iam_role.eks_node_group[each.value.cluster_key].arn
  subnet_ids = [
    for subnet in aws_subnet.private : subnet.id 
    if subnet.tags.VPC == each.value.cluster_config.vpc_name
  ]

  instance_types = each.value.ng_config.instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = each.value.ng_config.desired_size
    max_size     = each.value.ng_config.max_size
    min_size     = each.value.ng_config.min_size
  }

  update_config {
    max_unavailable = 1
  }

  # Launch template for custom configurations
  launch_template {
    id      = aws_launch_template.eks_nodes[each.value.cluster_key].id
    version = aws_launch_template.eks_nodes[each.value.cluster_key].latest_version
  }

  tags = {
    Name        = "${each.value.cluster_config.cluster_name}-${each.value.ng_key}"
    Cluster     = each.value.cluster_config.cluster_name
    NodeGroup   = each.value.ng_key
    VPC         = each.value.cluster_config.vpc_name
    Environment = local.accounts[split("_", each.value.cluster_key)[0]].environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_worker,
    aws_iam_role_policy_attachment.eks_node_group_cni,
    aws_iam_role_policy_attachment.eks_node_group_registry
  ]
}

# Launch template for EKS nodes
resource "aws_launch_template" "eks_nodes" {
  for_each = local.eks_clusters
  name     = "lt-eks-nodes-${each.key}"

  vpc_security_group_ids = [aws_security_group.eks_nodes[each.key].id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name = each.value.cluster_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "eks-node-${each.key}"
      Cluster = each.value.cluster_name
    }
  }

  tags = {
    Name    = "lt-eks-nodes-${each.key}"
    Cluster = each.value.cluster_name
  }
}

# EKS Add-ons
resource "aws_eks_addon" "vpc_cni" {
  for_each     = local.eks_clusters
  cluster_name = aws_eks_cluster.main[each.key].name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "coredns" {
  for_each     = local.eks_clusters
  cluster_name = aws_eks_cluster.main[each.key].name
  addon_name   = "coredns"
  
  depends_on = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  for_each     = local.eks_clusters
  cluster_name = aws_eks_cluster.main[each.key].name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "ebs_csi_driver" {
  for_each     = local.eks_clusters
  cluster_name = aws_eks_cluster.main[each.key].name
  addon_name   = "aws-ebs-csi-driver"
}
