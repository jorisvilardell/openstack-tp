variable "private_network_name" {
  description = "Existing tenant network the instances attach to."
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

variable "image_name" {
  description = "Glance image used for every instance."
  type        = string
  default     = "debian-12"
}

variable "flavor_name" {
  description = "Default flavor for every instance."
  type        = string
  default     = "m1.small"
}

variable "keypair_name" {
  description = "Existing Nova keypair injected into every instance."
  type        = string
  default     = "mapaire"
}

variable "ssh_source_cidr" {
  description = "Source range allowed to reach SSH on the load balancer."
  type        = string
  default     = "0.0.0.0/0"
}

variable "frontend_count" {
  description = "Number of frontend instances behind the load balancer."
  type        = number
  default     = 2
}

variable "lb_ip" {
  type    = string
  default = "192.168.10.11"
}

variable "frontend_ips" {
  type    = list(string)
  default = ["192.168.10.21", "192.168.10.22"]
}

variable "db_ip" {
  type    = string
  default = "192.168.10.31"
}

variable "nfs_ip" {
  type    = string
  default = "192.168.10.41"
}

variable "nfs_export" {
  description = "Directory exported by the NFS server and mounted by frontends."
  type        = string
  default     = "/srv/share"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_user" {
  type    = string
  default = "appuser"
}
