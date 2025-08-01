# Variables for the AWS Terraform infrastructure

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "ap-southeast-1"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "xentra-infra"
}

# Account ID variables - these should be set according to your AWS organization
variable "account_ids" {
  description = "Map of account names to account IDs"
  type        = map(string)
  default = {
    groapp-network           = "123456789001"
    groapp-access-dev        = "123456789002"
    groapp-access-test       = "123456789003"
    groapp-common           = "123456789004"
    groapp-accounting-dev-01 = "123456789005"
    groapp-accounting-test-01 = "123456789006"
  }
}

# Network configuration variables
variable "vpc_configurations" {
  description = "Map of VPC configurations"
  type = map(object({
    vpc_cidr = string
    environment = string
  }))
  default = {
    dev = {
      vpc_cidr    = "10.0.0.0/16"
      environment = "development"
    }
    host-dev = {
      vpc_cidr    = "10.7.0.0/16"
      environment = "development"
    }
    sharing-dev = {
      vpc_cidr    = "10.6.0.0/16"
      environment = "development"
    }
    testing = {
      vpc_cidr    = "10.2.0.0/16"
      environment = "testing"
    }
  }
}

# EKS configuration variables
variable "eks_cluster_version" {
  description = "Kubernetes version for EKS clusters"
  type        = string
  default     = "1.27"
}

variable "eks_node_instance_types" {
  description = "List of instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
}

variable "eks_node_capacity_type" {
  description = "Capacity type for EKS nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "eks_node_scaling" {
  description = "Default scaling configuration for EKS node groups"
  type = object({
    min_size     = number
    max_size     = number
    desired_size = number
  })
  default = {
    min_size     = 1
    max_size     = 3
    desired_size = 2
  }
}

# Redis configuration variables
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_num_cache_clusters" {
  description = "Number of cache clusters (nodes) in the replication group"
  type        = number
  default     = 1
}

variable "redis_snapshot_retention_limit" {
  description = "Number of days to retain Redis snapshots"
  type        = number
  default     = 7
}

variable "redis_snapshot_window" {
  description = "Daily time range for Redis snapshots"
  type        = string
  default     = "03:00-05:00"
}

variable "redis_maintenance_window" {
  description = "Weekly time range for Redis maintenance"
  type        = string
  default     = "sun:05:00-sun:07:00"
}

# Monitoring and logging variables
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for audit logging"
  type        = bool
  default     = true
}

# Security variables
variable "enable_at_rest_encryption" {
  description = "Enable at-rest encryption for supported services"
  type        = bool
  default     = true
}

variable "enable_transit_encryption" {
  description = "Enable transit encryption for supported services"
  type        = bool
  default     = true
}

# Tagging variables
variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "xentra-infra"
    ManagedBy   = "terraform"
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Cost optimization variables
variable "enable_spot_instances" {
  description = "Enable spot instances for EKS node groups"
  type        = bool
  default     = false
}

variable "enable_scheduled_scaling" {
  description = "Enable scheduled scaling for development environments"
  type        = bool
  default     = false
}
