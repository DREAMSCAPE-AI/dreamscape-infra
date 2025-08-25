variable "compartment_id" {
  description = "OCI compartment ID"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "dreamscape"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "VCN CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Public subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
  validation {
    condition     = can(cidrhost(var.private_subnet_cidr, 0))
    error_message = "Private subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "database_subnet_cidr" {
  description = "CIDR block for the database subnet"
  type        = string
  default     = "10.0.3.0/24"
  validation {
    condition     = can(cidrhost(var.database_subnet_cidr, 0))
    error_message = "Database subnet CIDR must be a valid IPv4 CIDR block."
  }
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