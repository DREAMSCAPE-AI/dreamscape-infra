output "vcn_id" {
  description = "ID of the VCN"
  value       = oci_core_vcn.main.id
}

output "vcn_cidr" {
  description = "CIDR block of the VCN"
  value       = var.vcn_cidr
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = oci_core_subnet.private.id
}

output "database_subnet_id" {
  description = "ID of the database subnet"
  value       = oci_core_subnet.database.id
}

output "internet_gateway_id" {
  description = "ID of the internet gateway"
  value       = oci_core_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway"
  value       = oci_core_nat_gateway.main.id
}

output "service_gateway_id" {
  description = "ID of the service gateway"
  value       = oci_core_service_gateway.main.id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = oci_core_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = oci_core_route_table.private.id
}

output "public_security_list_id" {
  description = "ID of the public security list"
  value       = oci_core_security_list.public.id
}

output "private_security_list_id" {
  description = "ID of the private security list"
  value       = oci_core_security_list.private.id
}

output "database_security_list_id" {
  description = "ID of the database security list"
  value       = oci_core_security_list.database.id
}

# Network Security Groups
output "auth_service_nsg_id" {
  description = "ID of the auth service network security group"
  value       = oci_core_network_security_group.auth_service.id
}

output "user_service_nsg_id" {
  description = "ID of the user service network security group"
  value       = oci_core_network_security_group.user_service.id
}

output "voyage_service_nsg_id" {
  description = "ID of the voyage service network security group"
  value       = oci_core_network_security_group.voyage_service.id
}

output "gateway_service_nsg_id" {
  description = "ID of the gateway service network security group"
  value       = oci_core_network_security_group.gateway_service.id
}

# Computed values for reference
output "availability_domains" {
  description = "List of availability domains in the region"
  value       = data.oci_identity_availability_domains.ads.availability_domains[*].name
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}