output "server_public_ips" {
  description = "Public IP addresses of K3s server nodes"
  value       = oci_core_instance.k3s_server[*].public_ip
}

output "server_private_ips" {
  description = "Private IP addresses of K3s server nodes"
  value       = oci_core_instance.k3s_server[*].private_ip
}

output "agent_private_ips" {
  description = "Private IP addresses of K3s agent nodes"
  value       = oci_core_instance.k3s_agent[*].private_ip
}

output "cluster_endpoint" {
  description = "K3s cluster API endpoint"
  value       = var.enable_load_balancer ? "https://${oci_load_balancer_load_balancer.k3s_lb[0].ip_addresses[0].ip_address}:6443" : "https://${oci_core_instance.k3s_server[0].public_ip}:6443"
}

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig"
  value       = "scp ubuntu@${oci_core_instance.k3s_server[0].public_ip}:/etc/rancher/k3s/k3s.yaml ./kubeconfig && sed -i 's/127.0.0.1/${oci_core_instance.k3s_server[0].public_ip}/g' ./kubeconfig"
}

output "ssh_commands" {
  description = "SSH commands to connect to nodes"
  value = {
    servers = [for i, instance in oci_core_instance.k3s_server : "ssh ubuntu@${instance.public_ip}"]
    agents  = [for i, instance in oci_core_instance.k3s_agent : "ssh -J ubuntu@${oci_core_instance.k3s_server[0].public_ip} ubuntu@${instance.private_ip}"]
  }
}

output "cluster_token" {
  description = "K3s cluster token (sensitive)"
  value       = var.k3s_token
  sensitive   = true
}

output "load_balancer_ip" {
  description = "Load balancer IP address"
  value       = var.enable_load_balancer ? oci_load_balancer_load_balancer.k3s_lb[0].ip_addresses[0].ip_address : null
}

output "server_nsg_id" {
  description = "Network security group ID for server nodes"
  value       = oci_core_network_security_group.k3s_server_nsg.id
}

output "agent_nsg_id" {
  description = "Network security group ID for agent nodes"
  value       = oci_core_network_security_group.k3s_agent_nsg.id
}