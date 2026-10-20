variable "private_network_name" {
  description = "Tenant network created for the stack."
  type        = string
  default     = "lemien"
}

variable "router_name" {
  description = "Router joining the tenant subnet to the external network."
  type        = string
  default     = "lemienroux"
}

variable "subnet_cidr" {
  description = "CIDR of the tenant subnet."
  type        = string
  default     = "192.168.10.0/24"
}

variable "allocation_pool_start" {
  description = "First DHCP address, left above the fixed instance addresses."
  type        = string
  default     = "192.168.10.100"
}

variable "allocation_pool_end" {
  type    = string
  default = "192.168.10.200"
}

variable "dns_nameservers" {
  description = "Resolvers handed to instances, required for cloud-init to fetch packages."
  type        = list(string)
  default     = ["8.8.8.8", "1.1.1.1"]
}

variable "external_network_name" {
  description = "External network that provides floating IPs."
  type        = string
  default     = "public"
}

variable "ssh_source_cidr" {
  description = "Source range allowed to reach SSH on the load balancer."
  type        = string
  default     = "0.0.0.0/0"
}
