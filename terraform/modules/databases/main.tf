terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

# PostgreSQL Database System
resource "oci_database_autonomous_database" "postgres" {
  count                          = var.enable_postgresql ? 1 : 0
  compartment_id                 = var.compartment_id
  display_name                   = "${var.project_name}-postgres-${var.environment}"
  db_name                        = "${var.project_name}${var.environment}db"
  admin_password                 = var.postgres_admin_password
  cpu_core_count                 = var.postgres_cpu_count
  data_storage_size_in_tbs       = var.postgres_storage_size
  db_workload                    = "OLTP"
  is_auto_scaling_enabled        = var.enable_auto_scaling
  subnet_id                      = var.database_subnet_id
  nsg_ids                        = [var.database_nsg_id]
  is_dedicated                   = false
  license_model                  = "LICENSE_INCLUDED"
  is_access_control_enabled      = true
  whitelisted_ips                = var.postgres_whitelisted_ips

  tags = var.common_tags

  lifecycle {
    ignore_changes = [admin_password]
  }
}

# Redis Cache (using OCI Cache with Redis)
resource "oci_redis_redis_cluster" "cache" {
  count          = var.enable_redis ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = "${var.project_name}-redis-${var.environment}"
  subnet_id      = var.database_subnet_id
  node_count     = var.redis_node_count
  node_memory_in_gbs = var.redis_memory_size
  software_version   = "REDIS_7_0"

  tags = var.common_tags
}

# MongoDB Atlas (external) - using data source for reference
resource "oci_core_instance" "mongodb" {
  count               = var.enable_mongodb ? 1 : 0
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  shape               = var.mongodb_shape
  display_name        = "${var.project_name}-mongodb-${var.environment}"

  create_vnic_details {
    subnet_id              = var.database_subnet_id
    assign_public_ip       = false
    nsg_ids                = [var.database_nsg_id]
  }

  source_details {
    source_type = "image"
    source_id   = var.ubuntu_image_id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/mongodb-init.sh", {
      mongodb_version     = var.mongodb_version
      mongodb_admin_user  = var.mongodb_admin_user
      mongodb_admin_pass  = var.mongodb_admin_password
      mongodb_replica_set = "${var.project_name}-rs-${var.environment}"
    }))
  }

  shape_config {
    ocpus         = var.mongodb_ocpus
    memory_in_gbs = var.mongodb_memory
  }

  tags = var.common_tags
}

# Elasticsearch (self-managed on OCI)
resource "oci_core_instance" "elasticsearch" {
  count               = var.enable_elasticsearch ? var.elasticsearch_nodes : 0
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  shape               = var.elasticsearch_shape
  display_name        = "${var.project_name}-elasticsearch-${count.index + 1}-${var.environment}"

  create_vnic_details {
    subnet_id              = var.database_subnet_id
    assign_public_ip       = false
    nsg_ids                = [var.database_nsg_id]
  }

  source_details {
    source_type = "image"
    source_id   = var.ubuntu_image_id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/elasticsearch-init.sh", {
      elasticsearch_version = var.elasticsearch_version
      cluster_name         = "${var.project_name}-es-${var.environment}"
      node_name           = "node-${count.index + 1}"
      is_master           = count.index < 3
      master_nodes        = [for i in range(min(3, var.elasticsearch_nodes)) : "${var.project_name}-elasticsearch-${i + 1}-${var.environment}"]
    }))
  }

  shape_config {
    ocpus         = var.elasticsearch_ocpus
    memory_in_gbs = var.elasticsearch_memory
  }

  tags = merge(var.common_tags, {
    ElasticsearchRole = count.index < 3 ? "master" : "data"
    NodeIndex        = count.index + 1
  })
}

# Block Storage for MongoDB
resource "oci_core_volume" "mongodb_data" {
  count               = var.enable_mongodb ? 1 : 0
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = "${var.project_name}-mongodb-data-${var.environment}"
  size_in_gbs         = var.mongodb_storage_size

  tags = var.common_tags
}

resource "oci_core_volume_attachment" "mongodb_data" {
  count           = var.enable_mongodb ? 1 : 0
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.mongodb[0].id
  volume_id       = oci_core_volume.mongodb_data[0].id
}

# Block Storage for Elasticsearch
resource "oci_core_volume" "elasticsearch_data" {
  count               = var.enable_elasticsearch ? var.elasticsearch_nodes : 0
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = "${var.project_name}-elasticsearch-data-${count.index + 1}-${var.environment}"
  size_in_gbs         = var.elasticsearch_storage_size

  tags = var.common_tags
}

resource "oci_core_volume_attachment" "elasticsearch_data" {
  count           = var.enable_elasticsearch ? var.elasticsearch_nodes : 0
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.elasticsearch[count.index].id
  volume_id       = oci_core_volume.elasticsearch_data[count.index].id
}

# Database backup configuration
resource "oci_objectstorage_bucket" "database_backups" {
  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "${var.project_name}-db-backups-${var.environment}"
  access_type    = "NoPublicAccess"

  versioning = "Enabled"

  retention_rules {
    display_name     = "backup-retention"
    duration {
      time_amount = var.backup_retention_days
      time_unit   = "DAYS"
    }
  }

  tags = var.common_tags
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}