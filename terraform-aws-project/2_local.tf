locals {
  region           = "ap-southeast-1"  # Singapore region 
  availability_zones = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  
  # Organization unit structure 
  organizational_units = {
    network    = "ou-network"
    access     = "ou-access"  
    common     = "ou-common"
    accounting = "ou-accounting"
  }

  # AWS Accounts 
  accounts = {
    groapp-network = {
      org_unit    = local.organizational_units.network
      name        = "groapp-network"
      account_id  = "123456789001"  # Replace with actual account ID
      environment = "shared"
    },
    groapp-access-dev = {
      org_unit    = local.organizational_units.access
      name        = "groapp-access-dev"
      account_id  = "123456789002"  # Replace with actual account ID
      environment = "dev"
    },
    groapp-access-test = {
      org_unit    = local.organizational_units.access
      name        = "groapp-access-test"
      account_id  = "123456789003"  # Replace with actual account ID
      environment = "test"
    },
    groapp-common = {
      org_unit    = local.organizational_units.common
      name        = "groapp-common"
      account_id  = "123456789004"  # Replace with actual account ID
      environment = "shared"
    },
    groapp-accounting-dev-01 = {
      org_unit    = local.organizational_units.accounting
      name        = "groapp-accounting-dev-01"
      account_id  = "123456789005"  # Replace with actual account ID
      environment = "dev"
    },
    groapp-accounting-test-01 = {
      org_unit    = local.organizational_units.accounting
      name        = "groapp-accounting-test-01"
      account_id  = "123456789006"  # Replace with actual account ID
      environment = "test"
    }
  }

  # VPC and subnet configurations
  networks = {
    dev = {
      vpc_cidr = "10.0.0.0/16"
      subnets = {
        private = {
          ap-southeast-1a = {
            cidr = "10.0.1.0/24"
            type = "private"
          }
          ap-southeast-1b = {
            cidr = "10.0.2.0/24"
            type = "private"
          }
          ap-southeast-1c = {
            cidr = "10.0.3.0/24"
            type = "private"
          }
        }
        public = {
          ap-southeast-1a = {
            cidr = "10.0.11.0/24"
            type = "public"
          }
          ap-southeast-1b = {
            cidr = "10.0.12.0/24"
            type = "public"
          }
          ap-southeast-1c = {
            cidr = "10.0.13.0/24"
            type = "public"
          }
        }
      }
    },
    host-dev = {
      vpc_cidr = "10.7.0.0/16"
      subnets = {
        private = {
          ap-southeast-1a = {
            cidr = "10.7.1.0/24"
            type = "private"
          }
          ap-southeast-1b = {
            cidr = "10.7.2.0/24"
            type = "private"
          }
          ap-southeast-1c = {
            cidr = "10.7.3.0/24"
            type = "private"
          }
        }
        public = {
          ap-southeast-1a = {
            cidr = "10.7.11.0/24"
            type = "public"
          }
          ap-southeast-1b = {
            cidr = "10.7.12.0/24"
            type = "public"
          }
          ap-southeast-1c = {
            cidr = "10.7.13.0/24"
            type = "public"
          }
        }
      }
    },
    sharing-dev = {
      vpc_cidr = "10.6.0.0/16"
      subnets = {
        private = {
          ap-southeast-1a = {
            cidr = "10.6.1.0/24"
            type = "private"
          }
          ap-southeast-1b = {
            cidr = "10.6.2.0/24"
            type = "private"
          }
          ap-southeast-1c = {
            cidr = "10.6.3.0/24"
            type = "private"
          }
        }
        public = {
          ap-southeast-1a = {
            cidr = "10.6.11.0/24"
            type = "public"
          }
          ap-southeast-1b = {
            cidr = "10.6.12.0/24"
            type = "public"
          }
          ap-southeast-1c = {
            cidr = "10.6.13.0/24"
            type = "public"
          }
        }
      }
    },
    testing = {
      vpc_cidr = "10.2.0.0/16"
      subnets = {
        private = {
          ap-southeast-1a = {
            cidr = "10.2.1.0/24"
            type = "private"
          }
          ap-southeast-1b = {
            cidr = "10.2.2.0/24"
            type = "private"
          }
          ap-southeast-1c = {
            cidr = "10.2.3.0/24"
            type = "private"
          }
        }
        public = {
          ap-southeast-1a = {
            cidr = "10.2.11.0/24"
            type = "public"
          }
          ap-southeast-1b = {
            cidr = "10.2.12.0/24"
            type = "public"
          }
          ap-southeast-1c = {
            cidr = "10.2.13.0/24"
            type = "public"
          }
        }
      }
    }
  }

  # Flatten subnets for easier resource creation
  subnets = flatten([
    for network_key, network_value in local.networks : [
      for subnet_type, subnet_zones in network_value.subnets : [
        for zone, zone_config in subnet_zones : {
          network_name    = network_key
          subnet_name     = "${network_key}-${subnet_type}-${zone}"
          cidr_block      = zone_config.cidr
          availability_zone = zone
          type           = zone_config.type
          vpc_cidr       = network_value.vpc_cidr
        }
      ]
    ]
  ])

  # EKS cluster configurations (equivalent to GKE)
  eks_clusters = {
    access_dev = {
      account_id    = local.accounts.groapp-access-dev.account_id
      cluster_name  = "access-dev"
      vpc_name      = "dev"
      node_groups = {
        general = {
          instance_types = ["t3.medium"]
          min_size      = 1
          max_size      = 3
          desired_size  = 2
        }
      }
    },
    access_test = {
      account_id    = local.accounts.groapp-access-test.account_id
      cluster_name  = "access-test"
      vpc_name      = "testing"
      node_groups = {
        general = {
          instance_types = ["t3.medium"]
          min_size      = 1
          max_size      = 3
          desired_size  = 2
        }
      }
    },
    networking = {
      account_id    = local.accounts.groapp-network.account_id
      cluster_name  = "groapp-network"
      vpc_name      = "host-dev"
      node_groups = {
        general = {
          instance_types = ["t3.medium"]
          min_size      = 1
          max_size      = 3
          desired_size  = 2
        }
      }
    },
    common_dev = {
      account_id    = local.accounts.groapp-common.account_id
      cluster_name  = "groapp-common"
      vpc_name      = "sharing-dev"
      node_groups = {
        general = {
          instance_types = ["t3.medium"]
          min_size      = 1
          max_size      = 3
          desired_size  = 2
        }
      }
    },
    accounting_dev = {
      account_id    = local.accounts.groapp-accounting-dev-01.account_id
      cluster_name  = "accounting-dev"
      vpc_name      = "dev"
      node_groups = {
        general = {
          instance_types = ["t3.medium"]
          min_size      = 1
          max_size      = 3
          desired_size  = 2
        }
      }
    },
    accounting_test = {
      account_id    = local.accounts.groapp-accounting-test-01.account_id
      cluster_name  = "accounting-test"
      vpc_name      = "testing"
      node_groups = {
        general = {
          instance_types = ["t3.medium"]
          min_size      = 1
          max_size      = 3
          desired_size  = 2
        }
      }
    }
  }

  # Account IDs for resource sharing
  network_account_id  = local.accounts.groapp-network.account_id
  shared_vpc_accounts = [
    local.accounts.groapp-access-dev.account_id,
    local.accounts.groapp-access-test.account_id,
    local.accounts.groapp-common.account_id,
    local.accounts.groapp-accounting-dev-01.account_id,
    local.accounts.groapp-accounting-test-01.account_id
  ]
}
