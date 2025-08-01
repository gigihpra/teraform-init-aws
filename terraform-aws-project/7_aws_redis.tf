# ElastiCache Redis clusters 
# ElastiCache subnet group
resource "aws_elasticache_subnet_group" "redis" {
  for_each   = local.networks
  name       = "redis-subnet-group-${each.key}"
  subnet_ids = [for subnet in aws_subnet.private : subnet.id if subnet.tags.VPC == each.key]

  tags = {
    Name = "redis-subnet-group-${each.key}"
    VPC  = each.key
  }
}

# Security group for Redis
resource "aws_security_group" "redis" {
  for_each    = local.networks
  name        = "sg-redis-${each.key}"
  description = "Security group for Redis cluster in ${each.key}"
  vpc_id      = aws_vpc.main[each.key].id

  # Allow Redis traffic from VPC
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [each.value.vpc_cidr]
  }

  # Allow Redis traffic from other VPCs
  dynamic "ingress" {
    for_each = { for name, config in local.networks : name => config if name != each.key }
    content {
      from_port   = 6379
      to_port     = 6379
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
    Name = "sg-redis-${each.key}"
    VPC  = each.key
  }
}

# ElastiCache Redis clusters
resource "aws_elasticache_replication_group" "redis" {
  for_each = {
    dev         = local.networks.dev
    host-dev    = local.networks.host-dev
    sharing-dev = local.networks.sharing-dev
    testing     = local.networks.testing
  }

  replication_group_id         = "redis-${each.key}"
  description                  = "Redis cluster for ${each.key} environment"
  
  node_type                    = "cache.t3.micro"
  port                         = 6379
  parameter_group_name         = aws_elasticache_parameter_group.redis[each.key].name
  
  num_cache_clusters           = 1
  
  engine_version               = "7.0"
  
  subnet_group_name            = aws_elasticache_subnet_group.redis[each.key].name
  security_group_ids           = [aws_security_group.redis[each.key].id]
  
  at_rest_encryption_enabled   = true
  transit_encryption_enabled   = true
  auth_token                   = random_password.redis_auth[each.key].result
  
  # Backup configuration
  snapshot_retention_limit     = 7
  snapshot_window             = "03:00-05:00"
  
  # Maintenance window
  maintenance_window          = "sun:05:00-sun:07:00"
  
  # Automatic failover
  automatic_failover_enabled  = false  # Set to true for Multi-AZ
  
  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis[each.key].name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  tags = {
    Name        = "redis-${each.key}"
    Environment = each.key
    VPC         = each.key
  }
}

# Parameter group for Redis
resource "aws_elasticache_parameter_group" "redis" {
  for_each = {
    dev         = local.networks.dev
    host-dev    = local.networks.host-dev
    sharing-dev = local.networks.sharing-dev
    testing     = local.networks.testing
  }

  family = "redis7.x"
  name   = "redis-params-${each.key}"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  tags = {
    Name        = "redis-params-${each.key}"
    Environment = each.key
  }
}

# Random password for Redis authentication
resource "random_password" "redis_auth" {
  for_each = {
    dev         = local.networks.dev
    host-dev    = local.networks.host-dev
    sharing-dev = local.networks.sharing-dev
    testing     = local.networks.testing
  }

  length  = 32
  special = true
}

# Store Redis auth tokens in AWS Secrets Manager
resource "aws_secretsmanager_secret" "redis_auth" {
  for_each = {
    dev         = local.networks.dev
    host-dev    = local.networks.host-dev
    sharing-dev = local.networks.sharing-dev
    testing     = local.networks.testing
  }

  name        = "redis-auth-${each.key}"
  description = "Redis authentication token for ${each.key} environment"

  tags = {
    Name        = "redis-auth-${each.key}"
    Environment = each.key
  }
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  for_each = {
    dev         = local.networks.dev
    host-dev    = local.networks.host-dev
    sharing-dev = local.networks.sharing-dev
    testing     = local.networks.testing
  }

  secret_id = aws_secretsmanager_secret.redis_auth[each.key].id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth[each.key].result
    endpoint   = aws_elasticache_replication_group.redis[each.key].primary_endpoint_address
    port       = aws_elasticache_replication_group.redis[each.key].port
  })
}

# CloudWatch log group for Redis
resource "aws_cloudwatch_log_group" "redis" {
  for_each = {
    dev         = local.networks.dev
    host-dev    = local.networks.host-dev
    sharing-dev = local.networks.sharing-dev
    testing     = local.networks.testing
  }

  name              = "/aws/elasticache/redis/${each.key}"
  retention_in_days = 30

  tags = {
    Name        = "redis-logs-${each.key}"
    Environment = each.key
  }
}

# CloudWatch alarms for Redis monitoring
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  for_each = {
    dev         = local.networks.dev
    host-dev    = local.networks.host-dev
    sharing-dev = local.networks.sharing-dev
    testing     = local.networks.testing
  }

  alarm_name          = "redis-cpu-utilization-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "75"
  alarm_description   = "This metric monitors Redis CPU utilization for ${each.key}"

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.redis[each.key].replication_group_id}-001"
  }

  tags = {
    Name        = "redis-cpu-alarm-${each.key}"
    Environment = each.key
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  for_each = {
    dev         = local.networks.dev
    host-dev    = local.networks.host-dev
    sharing-dev = local.networks.sharing-dev
    testing     = local.networks.testing
  }

  alarm_name          = "redis-memory-utilization-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Redis memory utilization for ${each.key}"

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.redis[each.key].replication_group_id}-001"
  }

  tags = {
    Name        = "redis-memory-alarm-${each.key}"
    Environment = each.key
  }
}
