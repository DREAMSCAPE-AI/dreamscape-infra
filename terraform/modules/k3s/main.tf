terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

resource "oci_core_instance" "k3s_server" {
  count               = var.server_count
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.server_shape

  display_name = "${var.cluster_name}-server-${count.index + 1}"

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.assign_public_ip
    nsg_ids          = [oci_core_network_security_group.k3s_server_nsg.id]
  }

  source_details {
    source_type = "image"
    source_id   = var.image_id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init-server.yaml", {
      k3s_token    = var.k3s_token
      cluster_name = var.cluster_name
      node_index   = count.index
      is_first     = count.index == 0
    }))
  }

  shape_config {
    ocpus         = var.server_ocpus
    memory_in_gbs = var.server_memory
  }

  tags = merge(var.common_tags, {
    Role = "k3s-server"
    Node = "server-${count.index + 1}"
  })
}

resource "oci_core_instance" "k3s_agent" {
  count               = var.agent_count
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.agent_shape

  display_name = "${var.cluster_name}-agent-${count.index + 1}"

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = false
    nsg_ids          = [oci_core_network_security_group.k3s_agent_nsg.id]
  }

  source_details {
    source_type = "image"
    source_id   = var.image_id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init-agent.yaml", {
      k3s_token    = var.k3s_token
      server_url   = "https://${oci_core_instance.k3s_server[0].private_ip}:6443"
      cluster_name = var.cluster_name
      node_index   = count.index
    }))
  }

  shape_config {
    ocpus         = var.agent_ocpus
    memory_in_gbs = var.agent_memory
  }

  tags = merge(var.common_tags, {
    Role = "k3s-agent"
    Node = "agent-${count.index + 1}"
  })

  depends_on = [oci_core_instance.k3s_server]
}

resource "oci_core_network_security_group" "k3s_server_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "${var.cluster_name}-server-nsg"

  tags = var.common_tags
}

resource "oci_core_network_security_group" "k3s_agent_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "${var.cluster_name}-agent-nsg"

  tags = var.common_tags
}

# Security rules for K3s server
resource "oci_core_network_security_group_security_rule" "server_ingress_api" {
  network_security_group_id = oci_core_network_security_group.k3s_server_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }

  description = "K3s API Server"
}

resource "oci_core_network_security_group_security_rule" "server_ingress_ssh" {
  network_security_group_id = oci_core_network_security_group.k3s_server_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }

  description = "SSH Access"
}

resource "oci_core_network_security_group_security_rule" "server_ingress_http" {
  network_security_group_id = oci_core_network_security_group.k3s_server_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }

  description = "HTTP Traffic"
}

resource "oci_core_network_security_group_security_rule" "server_ingress_https" {
  network_security_group_id = oci_core_network_security_group.k3s_server_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }

  description = "HTTPS Traffic"
}

resource "oci_core_network_security_group_security_rule" "server_egress_all" {
  network_security_group_id = oci_core_network_security_group.k3s_server_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"

  description = "All outbound traffic"
}

# Security rules for K3s agents
resource "oci_core_network_security_group_security_rule" "agent_ingress_ssh" {
  network_security_group_id = oci_core_network_security_group.k3s_agent_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = var.vpc_cidr
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }

  description = "SSH Access from VPC"
}

resource "oci_core_network_security_group_security_rule" "agent_ingress_kubelet" {
  network_security_group_id = oci_core_network_security_group.k3s_agent_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = var.vpc_cidr
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 10250
      max = 10250
    }
  }

  description = "Kubelet API"
}

resource "oci_core_network_security_group_security_rule" "agent_egress_all" {
  network_security_group_id = oci_core_network_security_group.k3s_agent_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"

  description = "All outbound traffic"
}

# Load Balancer for high availability
resource "oci_load_balancer_load_balancer" "k3s_lb" {
  count          = var.enable_load_balancer ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = "${var.cluster_name}-lb"
  shape          = "flexible"

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 100
  }

  subnet_ids = [var.public_subnet_id]

  tags = var.common_tags
}

resource "oci_load_balancer_backend_set" "k3s_api_backend_set" {
  count            = var.enable_load_balancer ? 1 : 0
  name             = "k3s-api-backend-set"
  load_balancer_id = oci_load_balancer_load_balancer.k3s_lb[0].id
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = "TCP"
    port     = 6443
  }
}

resource "oci_load_balancer_backend" "k3s_api_backend" {
  count            = var.enable_load_balancer ? var.server_count : 0
  backendset_name  = oci_load_balancer_backend_set.k3s_api_backend_set[0].name
  load_balancer_id = oci_load_balancer_load_balancer.k3s_lb[0].id
  ip_address       = oci_core_instance.k3s_server[count.index].private_ip
  port             = 6443
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_listener" "k3s_api_listener" {
  count                    = var.enable_load_balancer ? 1 : 0
  load_balancer_id         = oci_load_balancer_load_balancer.k3s_lb[0].id
  name                     = "k3s-api-listener"
  default_backend_set_name = oci_load_balancer_backend_set.k3s_api_backend_set[0].name
  port                     = 6443
  protocol                 = "TCP"
}