# Output values for other modules or external use

# VPC Information
output "vpc_ids" {
  description = "Map of VPC names to VPC IDs"
  value = {
    for k, v in aws_vpc.main : k => v.id
  }
}

output "vpc_cidrs" {
  description = "Map of VPC names to CIDR blocks"
  value = {
    for k, v in local.networks : k => v.vpc_cidr
  }
}

# Subnet Information
output "private_subnet_ids" {
  description = "Map of private subnet names to subnet IDs"
  value = {
    for k, v in aws_subnet.private : k => v.id
  }
}

output "public_subnet_ids" {
  description = "Map of public subnet names to subnet IDs"
  value = {
    for k, v in aws_subnet.public : k => v.id
  }
}

# EKS Cluster Information
output "eks_cluster_endpoints" {
  description = "Map of EKS cluster names to their endpoints"
  value = {
    for k, v in aws_eks_cluster.main : k => v.endpoint
  }
}

output "eks_cluster_security_group_ids" {
  description = "Map of EKS cluster names to their security group IDs"
  value = {
    for k, v in aws_eks_cluster.main : k => v.vpc_config[0].cluster_security_group_id
  }
}

output "eks_cluster_oidc_issuer_urls" {
  description = "Map of EKS cluster names to their OIDC issuer URLs"
  value = {
    for k, v in aws_eks_cluster.main : k => v.identity[0].oidc[0].issuer
  }
}

output "eks_cluster_certificate_authority_data" {
  description = "Map of EKS cluster names to their certificate authority data"
  value = {
    for k, v in aws_eks_cluster.main : k => v.certificate_authority[0].data
  }
  sensitive = true
}

# Redis Information
output "redis_endpoints" {
  description = "Map of Redis cluster names to their endpoints"
  value = {
    for k, v in aws_elasticache_replication_group.redis : k => v.primary_endpoint_address
  }
}

output "redis_ports" {
  description = "Map of Redis cluster names to their ports"
  value = {
    for k, v in aws_elasticache_replication_group.redis : k => v.port
  }
}

output "redis_auth_secret_arns" {
  description = "Map of Redis cluster names to their auth secret ARNs"
  value = {
    for k, v in aws_secretsmanager_secret.redis_auth : k => v.arn
  }
}

# Transit Gateway Information
output "transit_gateway_id" {
  description = "Transit Gateway ID for VPC connectivity"
  value       = aws_ec2_transit_gateway.main.id
}

output "transit_gateway_route_table_id" {
  description = "Transit Gateway Route Table ID"
  value       = aws_ec2_transit_gateway_route_table.main.id
}

# Account Information
output "account_configurations" {
  description = "Map of account configurations"
  value = {
    for k, v in local.accounts : k => {
      account_id  = v.account_id
      environment = v.environment
      org_unit    = v.org_unit
    }
  }
}

# IAM Role ARNs
output "eks_cluster_role_arns" {
  description = "Map of EKS cluster names to their IAM role ARNs"
  value = {
    for k, v in aws_iam_role.eks_cluster : k => v.arn
  }
}

output "eks_node_group_role_arns" {
  description = "Map of EKS cluster names to their node group IAM role ARNs"
  value = {
    for k, v in aws_iam_role.eks_node_group : k => v.arn
  }
}

# Security Group IDs
output "eks_cluster_security_groups" {
  description = "Map of EKS cluster names to their security group IDs"
  value = {
    for k, v in aws_security_group.eks_cluster : k => v.id
  }
}

output "eks_node_security_groups" {
  description = "Map of EKS cluster names to their node security group IDs"  
  value = {
    for k, v in aws_security_group.eks_nodes : k => v.id
  }
}

output "redis_security_groups" {
  description = "Map of Redis cluster names to their security group IDs"
  value = {
    for k, v in aws_security_group.redis : k => v.id
  }
}

# KMS Key Information
output "eks_kms_key_arns" {
  description = "Map of EKS cluster names to their KMS key ARNs"
  value = {
    for k, v in aws_kms_key.eks : k => v.arn
  }
}

# CloudWatch Log Groups
output "eks_log_group_names" {
  description = "Map of EKS cluster names to their CloudWatch log group names"
  value = {
    for k, v in aws_cloudwatch_log_group.eks_cluster : k => v.name
  }
}

output "redis_log_group_names" {
  description = "Map of Redis cluster names to their CloudWatch log group names"
  value = {
    for k, v in aws_cloudwatch_log_group.redis : k => v.name
  }
}

# Region Information
output "region" {
  description = "AWS region where resources are deployed"
  value       = local.region
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = local.availability_zones
}
