variable "compartment_id" {
  description = "OCI compartment ID"
  type        = string
}

variable "availability_domain" {
  description = "OCI availability domain"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for K3s instances"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for load balancer"
  type        = string
  default     = ""
}

variable "vcn_id" {
  description = "VCN ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "dreamscape-k3s"
}

variable "k3s_token" {
  description = "K3s cluster token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "image_id" {
  description = "OCI image ID (Ubuntu 22.04 recommended)"
  type        = string
}

variable "server_count" {
  description = "Number of K3s server nodes"
  type        = number
  default     = 1
  validation {
    condition     = var.server_count >= 1 && var.server_count <= 5
    error_message = "Server count must be between 1 and 5."
  }
}

variable "agent_count" {
  description = "Number of K3s agent nodes"
  type        = number
  default     = 2
  validation {
    condition     = var.agent_count >= 0 && var.agent_count <= 10
    error_message = "Agent count must be between 0 and 10."
  }
}

variable "server_shape" {
  description = "OCI shape for server nodes"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "agent_shape" {
  description = "OCI shape for agent nodes"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "server_ocpus" {
  description = "Number of OCPUs for server nodes"
  type        = number
  default     = 2
}

variable "server_memory" {
  description = "Memory in GBs for server nodes"
  type        = number
  default     = 12
}

variable "agent_ocpus" {
  description = "Number of OCPUs for agent nodes"
  type        = number
  default     = 1
}

variable "agent_memory" {
  description = "Memory in GBs for agent nodes"
  type        = number
  default     = 6
}

variable "assign_public_ip" {
  description = "Assign public IP to server nodes"
  type        = bool
  default     = true
}

variable "enable_load_balancer" {
  description = "Enable load balancer for high availability"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "DreamScape"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}