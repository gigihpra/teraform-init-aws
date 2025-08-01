# Resource Access Manager (RAM) for VPC sharing 

# Create RAM resource share for VPC sharing
resource "aws_ram_resource_share" "vpc_share" {
  for_each                  = local.networks
  name                      = "vpc-share-${each.key}"
  allow_external_principals = false

  tags = {
    Name        = "vpc-share-${each.key}"
    Environment = "shared"
    VPC         = each.key
  }
}

# Share subnets with other accounts
resource "aws_ram_resource_association" "subnet_share" {
  for_each           = {
    for subnet in local.subnets : subnet.subnet_name => subnet
    if subnet.type == "private"  # Only share private subnets
  }
  
  resource_arn       = aws_subnet.private[each.key].arn
  resource_share_arn = aws_ram_resource_share.vpc_share[each.value.network_name].arn
}

# Invite accounts to the resource share
resource "aws_ram_principal_association" "account_invitation" {
  for_each = {
    for combo in setproduct(keys(local.networks), local.shared_vpc_accounts) : 
    "${combo[0]}-${combo[1]}" => {
      network_name = combo[0]
      account_id   = combo[1]
    }
  }

  principal          = each.value.account_id
  resource_share_arn = aws_ram_resource_share.vpc_share[each.value.network_name].arn
}

# Transit Gateway for inter-VPC communication 
resource "aws_ec2_transit_gateway" "main" {
  description                     = "Main Transit Gateway for VPC connectivity"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = {
    Name = "tgw-main"
  }
}

# Transit Gateway VPC attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_attachment" {
  for_each           = local.networks
  subnet_ids         = [for subnet in aws_subnet.private : subnet.id if subnet.tags.VPC == each.key]
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.main[each.key].id

  tags = {
    Name = "tgw-attachment-${each.key}"
    VPC  = each.key
  }

  depends_on = [aws_subnet.private]
}

# Transit Gateway Route Table
resource "aws_ec2_transit_gateway_route_table" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "tgw-rt-main"
  }
}

# Routes between VPCs 
locals {
  # Define VPC connectivity matrix
  vpc_connectivity = {
    "host-dev"    = ["dev", "sharing-dev", "testing"],
    "dev"         = ["host-dev"],
    "sharing-dev" = ["host-dev"],
    "testing"     = ["host-dev"]
  }

  # Create route combinations
  tgw_routes = flatten([
    for source_vpc, target_vpcs in local.vpc_connectivity : [
      for target_vpc in target_vpcs : {
        source_vpc = source_vpc
        target_vpc = target_vpc
        route_name = "route-${source_vpc}-to-${target_vpc}"
        destination_cidr = local.networks[target_vpc].vpc_cidr
      }
    ]
  ])
}

# Transit Gateway routes for inter-VPC communication
resource "aws_ec2_transit_gateway_route" "vpc_routes" {
  for_each               = { for route in local.tgw_routes : route.route_name => route }
  destination_cidr_block = each.value.destination_cidr
  route_table_id         = aws_ec2_transit_gateway_route_table.main.id
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.vpc_attachment[each.value.target_vpc].id
}

# Associate route table with attachments
resource "aws_ec2_transit_gateway_route_table_association" "vpc_association" {
  for_each               = local.networks
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.vpc_attachment[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

# Propagate routes
resource "aws_ec2_transit_gateway_route_table_propagation" "vpc_propagation" {
  for_each               = local.networks
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.vpc_attachment[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

# Security groups for cross-VPC communication
resource "aws_security_group" "cross_vpc_communication" {
  for_each    = local.networks
  name        = "sg-cross-vpc-${each.key}"
  description = "Security group for cross-VPC communication for ${each.key}"
  vpc_id      = aws_vpc.main[each.key].id

  # Allow all internal traffic between VPCs
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [for network in local.networks : network.vpc_cidr]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [for network in local.networks : network.vpc_cidr]
  }

  # ICMP for ping
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [for network in local.networks : network.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-cross-vpc-${each.key}"
    VPC  = each.key
  }
}
