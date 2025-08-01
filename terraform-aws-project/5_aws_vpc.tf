# VPC Resources 

# Create VPCs
resource "aws_vpc" "main" {
  for_each             = local.networks
  cidr_block           = each.value.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpc-${each.key}"
    Type = each.key
  }
}

# Internet Gateways for public subnets
resource "aws_internet_gateway" "main" {
  for_each = local.networks
  vpc_id   = aws_vpc.main[each.key].id

  tags = {
    Name = "igw-${each.key}"
    VPC  = each.key
  }
}

# Create public subnets
resource "aws_subnet" "public" {
  for_each = {
    for subnet in local.subnets : subnet.subnet_name => subnet
    if subnet.type == "public"
  }

  vpc_id                  = aws_vpc.main[each.value.network_name].id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = each.key
    Type = "public"
    VPC  = each.value.network_name
    Zone = each.value.availability_zone
  }
}

# Create private subnets
resource "aws_subnet" "private" {
  for_each = {
    for subnet in local.subnets : subnet.subnet_name => subnet
    if subnet.type == "private"
  }

  vpc_id            = aws_vpc.main[each.value.network_name].id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = each.key
    Type = "private"
    VPC  = each.value.network_name
    Zone = each.value.availability_zone
    # EKS tags for subnet discovery
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/access-dev" = "shared"
    "kubernetes.io/cluster/access-test" = "shared"
    "kubernetes.io/cluster/groapp-network" = "shared"
    "kubernetes.io/cluster/groapp-common" = "shared"
    "kubernetes.io/cluster/accounting-dev" = "shared"
    "kubernetes.io/cluster/accounting-test" = "shared"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  for_each = {
    for subnet in local.subnets : subnet.subnet_name => subnet
    if subnet.type == "public"
  }

  domain = "vpc"

  tags = {
    Name = "eip-nat-${each.key}"
    VPC  = each.value.network_name
    Zone = each.value.availability_zone
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways for private subnet internet access
resource "aws_nat_gateway" "main" {
  for_each = {
    for subnet in local.subnets : subnet.subnet_name => subnet
    if subnet.type == "public"
  }

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "nat-${each.key}"
    VPC  = each.value.network_name
    Zone = each.value.availability_zone
  }

  depends_on = [aws_internet_gateway.main]
}

# Route tables for public subnets
resource "aws_route_table" "public" {
  for_each = local.networks
  vpc_id   = aws_vpc.main[each.key].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[each.key].id
  }

  tags = {
    Name = "rt-public-${each.key}"
    Type = "public"
    VPC  = each.key
  }
}

# Route tables for private subnets
resource "aws_route_table" "private" {
  for_each = {
    for subnet in local.subnets : subnet.subnet_name => subnet
    if subnet.type == "private"
  }

  vpc_id = aws_vpc.main[each.value.network_name].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main["${each.value.network_name}-public-${each.value.availability_zone}"].id
  }

  tags = {
    Name = "rt-private-${each.key}"
    Type = "private"
    VPC  = each.value.network_name
    Zone = each.value.availability_zone
  }
}

# Associate public subnets with public route tables
resource "aws_route_table_association" "public" {
  for_each = {
    for subnet in local.subnets : subnet.subnet_name => subnet
    if subnet.type == "public"
  }

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.value.network_name].id
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  for_each = {
    for subnet in local.subnets : subnet.subnet_name => subnet
    if subnet.type == "private"
  }

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

# VPC Flow Logs for network monitoring
resource "aws_flow_log" "vpc_flow_log" {
  for_each        = local.networks
  iam_role_arn    = aws_iam_role.flow_log[each.key].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log[each.key].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main[each.key].id

  tags = {
    Name = "flow-log-${each.key}"
    VPC  = each.key
  }
}

# CloudWatch log group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  for_each          = local.networks
  name              = "/aws/vpc/flowlogs/${each.key}"
  retention_in_days = 30

  tags = {
    Name = "flow-log-group-${each.key}"
    VPC  = each.key
  }
}

# IAM role for VPC Flow Logs
resource "aws_iam_role" "flow_log" {
  for_each = local.networks
  name     = "flow-log-role-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "flow-log-role-${each.key}"
    VPC  = each.key
  }
}

# IAM policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_log" {
  for_each = local.networks
  name     = "flow-log-policy-${each.key}"
  role     = aws_iam_role.flow_log[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Network ACLs for additional security
resource "aws_network_acl" "main" {
  for_each   = local.networks
  vpc_id     = aws_vpc.main[each.key].id
  subnet_ids = [for subnet in aws_subnet.private : subnet.id if subnet.tags.VPC == each.key]

  # Allow inbound traffic from VPC CIDR
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = each.value.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow inbound traffic from other VPCs
  dynamic "ingress" {
    for_each = { for name, config in local.networks : name => config if name != each.key }
    content {
      protocol   = "-1"
      rule_no    = 200 + index(keys(local.networks), ingress.key)
      action     = "allow"
      cidr_block = ingress.value.vpc_cidr
      from_port  = 0
      to_port    = 0
    }
  }

  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "nacl-${each.key}"
    VPC  = each.key
  }

  depends_on = [aws_subnet.private]
}
