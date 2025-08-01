# Terraform AWS Infrastructure for Xentra

This directory contains Terraform configuration files for deploying AWS infrastructure 

## Architecture Overview

This Terraform configuration creates a multi-account AWS infrastructure with the following components:

### Core Components

1. **AWS Accounts** 
   - `groapp-network` - Network host account
   - `groapp-access-dev` - Development access services
   - `groapp-access-test` - Testing access services  
   - `groapp-common` - Shared common services
   - `groapp-accounting-dev-01` - Development accounting services
   - `groapp-accounting-test-01` - Testing accounting services

2. **VPC Networks** 
   - `dev` - Development network (10.0.0.0/16)
   - `host-dev` - Host development network (10.7.0.0/16)
   - `sharing-dev` - Shared development network (10.6.0.0/16)
   - `testing` - Testing network (10.2.0.0/16)

3. **EKS Clusters** (equivalent to GKE Clusters)
   - Managed Kubernetes clusters in each environment
   - Auto-scaling node groups
   - Integrated with VPC networking

4. **ElastiCache Redis** (equivalent to Cloud Memorystore)
   - Redis clusters for caching
   - Encryption at rest and in transit
   - Cross-VPC connectivity

5. **Transit Gateway** (equivalent to VPC Peering)
   - Centralized connectivity between VPCs
   - Simplified routing and network management

6. **Resource Access Manager (RAM)** (equivalent to Shared VPC)
   - Share network resources across accounts
   - Centralized network management

## File Structure

```
terraform-aws-project/
├── 1_init.tf                      # Provider configuration
├── 2_local.tf                     # Local values and variables
├── 3_aws_accounts.tf              # Account setup and IAM roles
├── 4_aws_shared_networking.tf     # Resource sharing and transit gateway
├── 5_aws_vpc.tf                   # VPC, subnets, and networking
├── 6_aws_eks.tf                   # EKS clusters and node groups
├── 7_aws_redis.tf                 # ElastiCache Redis clusters
├── user_data.sh                   # EKS node initialization script
├── outputs.tf                     # Output values
├── variables.tf                   # Input variables
├── README.md                      # This file
└── modules/
    └── eks/                       # EKS module (for future use)
```


## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform** installed (version >= 1.0)
3. **AWS Organizations** set up with multiple accounts
4. **Appropriate IAM permissions** for resource creation

## Usage

### 1. Configure Variables

Edit the variables in `2_local.tf` or create a `terraform.tfvars` file:

```hcl
# terraform.tfvars
region = "ap-southeast-1"

account_ids = {
  groapp-network           = "111111111111"  # Replace with actual account IDs
  groapp-access-dev        = "222222222222"
  groapp-access-test       = "333333333333"
  groapp-common           = "444444444444"
  groapp-accounting-dev-01 = "555555555555"
  groapp-accounting-test-01 = "666666666666"
}
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan the Deployment

```bash
terraform plan
```

### 4. Apply the Configuration

```bash
terraform apply
```

## Security Considerations

1. **Encryption**: All services use encryption at rest and in transit
2. **Network Security**: Security groups and NACLs for defense in depth
3. **IAM**: Least privilege access with role-based permissions
4. **Audit Logging**: CloudTrail enabled for all accounts
5. **Secrets Management**: Redis auth tokens stored in Secrets Manager

## Monitoring and Logging

1. **VPC Flow Logs**: Network traffic monitoring
2. **CloudWatch Logs**: Application and system logs
3. **CloudWatch Metrics**: Performance monitoring
4. **CloudWatch Alarms**: Automated alerting

## Cost Optimization

1. **Spot Instances**: Optional for development environments
2. **Right-sizing**: T3 instances for cost-effective compute
3. **Reserved Capacity**: Consider for production workloads
4. **Scheduled Scaling**: Auto-scaling based on usage patterns

## Networking Details

### VPC CIDR Allocation
- **dev**: 10.0.0.0/16
- **host-dev**: 10.7.0.0/16  
- **sharing-dev**: 10.6.0.0/16
- **testing**: 10.2.0.0/16

### Subnet Structure
Each VPC has:
- 3 public subnets (one per AZ)
- 3 private subnets (one per AZ)
- NAT Gateways for private subnet internet access

### Connectivity Matrix
- **host-dev** connects to: dev, sharing-dev, testing
- **dev** connects to: host-dev
- **sharing-dev** connects to: host-dev
- **testing** connects to: host-dev

## Outputs

The configuration provides outputs for:
- VPC IDs and CIDR blocks
- Subnet IDs (public and private)
- EKS cluster endpoints and security groups
- Redis endpoints and authentication secrets
- IAM role ARNs
- Security group IDs

## Customization

### Adding New VPCs
1. Add to `local.networks` in `2_local.tf`
2. Update connectivity matrix in `4_aws_shared_networking.tf`
3. Add Redis cluster if needed in `7_aws_redis.tf`

### Adding New EKS Clusters
1. Add to `local.eks_clusters` in `2_local.tf`
2. Configure node groups and scaling parameters

### Adding New Environments
1. Create new account entry in `local.accounts`
2. Add VPC configuration
3. Add EKS cluster configuration
4. Update networking connectivity

## Troubleshooting

### Common Issues

1. **Account ID Mismatch**: Ensure account IDs in variables match your AWS accounts
2. **Insufficient Permissions**: Verify IAM permissions for cross-account access
3. **VPC Limits**: Check AWS service limits for VPCs and subnets
4. **EKS Version**: Ensure EKS version is supported in your region

### Useful Commands

```bash
# Check Terraform state
terraform state list

# Show specific resource
terraform state show aws_eks_cluster.main[\"access_dev\"]

# Import existing resource
terraform import aws_vpc.main[\"dev\"] vpc-xxxxxxxxx

# Refresh state
terraform refresh
```

## Support

For issues or questions:
1. Check AWS documentation for service-specific issues
2. Review Terraform AWS provider documentation
3. Check CloudWatch logs for runtime issues
4. Use AWS CLI for manual verification

## Version History
- Supports: Multi-account setup, VPC networking, EKS clusters, ElastiCache Redis
- Compatible with: Terraform >= 1.0, AWS Provider ~> 5.0
