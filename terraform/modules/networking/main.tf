terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

# Virtual Cloud Network
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.project_name}-vcn-${var.environment}"
  dns_label      = "${var.project_name}${var.environment}"

  tags = var.common_tags
}

# Internet Gateway
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-igw-${var.environment}"
  enabled        = true

  tags = var.common_tags
}

# NAT Gateway
resource "oci_core_nat_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-nat-${var.environment}"

  tags = var.common_tags
}

# Service Gateway
resource "oci_core_service_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-sgw-${var.environment}"

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }

  tags = var.common_tags
}

data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# Public Subnet
resource "oci_core_subnet" "public" {
  compartment_id      = var.compartment_id
  vcn_id              = oci_core_vcn.main.id
  cidr_block          = var.public_subnet_cidr
  display_name        = "${var.project_name}-public-subnet-${var.environment}"
  dns_label           = "public${var.environment}"
  security_list_ids   = [oci_core_security_list.public.id]
  route_table_id      = oci_core_route_table.public.id
  dhcp_options_id     = oci_core_vcn.main.default_dhcp_options_id
  prohibit_public_ip_on_vnic = false

  tags = var.common_tags
}

# Private Subnet
resource "oci_core_subnet" "private" {
  compartment_id      = var.compartment_id
  vcn_id              = oci_core_vcn.main.id
  cidr_block          = var.private_subnet_cidr
  display_name        = "${var.project_name}-private-subnet-${var.environment}"
  dns_label           = "private${var.environment}"
  security_list_ids   = [oci_core_security_list.private.id]
  route_table_id      = oci_core_route_table.private.id
  dhcp_options_id     = oci_core_vcn.main.default_dhcp_options_id
  prohibit_public_ip_on_vnic = true

  tags = var.common_tags
}

# Database Subnet
resource "oci_core_subnet" "database" {
  compartment_id      = var.compartment_id
  vcn_id              = oci_core_vcn.main.id
  cidr_block          = var.database_subnet_cidr
  display_name        = "${var.project_name}-database-subnet-${var.environment}"
  dns_label           = "database${var.environment}"
  security_list_ids   = [oci_core_security_list.database.id]
  route_table_id      = oci_core_route_table.private.id
  dhcp_options_id     = oci_core_vcn.main.default_dhcp_options_id
  prohibit_public_ip_on_vnic = true

  tags = var.common_tags
}

# Public Route Table
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-public-rt-${var.environment}"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }

  tags = var.common_tags
}

# Private Route Table
resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-private-rt-${var.environment}"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.main.id
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.main.id
  }

  tags = var.common_tags
}

# Public Security List
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-public-sl-${var.environment}"

  # Egress Rules
  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  # Ingress Rules
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  tags = var.common_tags
}

# Private Security List
resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-private-sl-${var.environment}"

  # Egress Rules
  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  # Ingress Rules - VCN traffic
  ingress_security_rules {
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "all"
  }

  tags = var.common_tags
}

# Database Security List
resource "oci_core_security_list" "database" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-database-sl-${var.environment}"

  # Egress Rules - Only to service gateway
  egress_security_rules {
    destination      = data.oci_core_services.all_services.services[0].cidr_block
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol         = "6"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Ingress Rules - Only from application subnets
  ingress_security_rules {
    source      = var.private_subnet_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 5432
      max = 5432
    }
  }

  ingress_security_rules {
    source      = var.private_subnet_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 27017
      max = 27017
    }
  }

  ingress_security_rules {
    source      = var.private_subnet_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 6379
      max = 6379
    }
  }

  tags = var.common_tags
}

# Network Security Groups for microservices
resource "oci_core_network_security_group" "auth_service" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-auth-nsg-${var.environment}"

  tags = var.common_tags
}

resource "oci_core_network_security_group" "user_service" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-user-nsg-${var.environment}"

  tags = var.common_tags
}

resource "oci_core_network_security_group" "voyage_service" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-voyage-nsg-${var.environment}"

  tags = var.common_tags
}

resource "oci_core_network_security_group" "gateway_service" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-gateway-nsg-${var.environment}"

  tags = var.common_tags
}

# NSG Rules for Auth Service
resource "oci_core_network_security_group_security_rule" "auth_ingress_http" {
  network_security_group_id = oci_core_network_security_group.auth_service.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = var.vcn_cidr
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 3001
      max = 3001
    }
  }
}

resource "oci_core_network_security_group_security_rule" "auth_egress_all" {
  network_security_group_id = oci_core_network_security_group.auth_service.id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"
}

# NSG Rules for User Service
resource "oci_core_network_security_group_security_rule" "user_ingress_http" {
  network_security_group_id = oci_core_network_security_group.user_service.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = var.vcn_cidr
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 3002
      max = 3002
    }
  }
}

resource "oci_core_network_security_group_security_rule" "user_egress_all" {
  network_security_group_id = oci_core_network_security_group.user_service.id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"
}

# NSG Rules for Voyage Service
resource "oci_core_network_security_group_security_rule" "voyage_ingress_http" {
  network_security_group_id = oci_core_network_security_group.voyage_service.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = var.vcn_cidr
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 3003
      max = 3003
    }
  }
}

resource "oci_core_network_security_group_security_rule" "voyage_egress_all" {
  network_security_group_id = oci_core_network_security_group.voyage_service.id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"
}

# NSG Rules for Gateway Service
resource "oci_core_network_security_group_security_rule" "gateway_ingress_http" {
  network_security_group_id = oci_core_network_security_group.gateway_service.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = var.vcn_cidr
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 3000
      max = 3000
    }
  }
}

resource "oci_core_network_security_group_security_rule" "gateway_egress_all" {
  network_security_group_id = oci_core_network_security_group.gateway_service.id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"
}