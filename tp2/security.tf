resource "openstack_networking_secgroup_v2" "lb" {
  name        = "sg-lb"
  description = "Public entry point: HTTP/HTTPS from anywhere, SSH from admins"
}

resource "openstack_networking_secgroup_rule_v2" "lb_http" {
  security_group_id = openstack_networking_secgroup_v2.lb.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "lb_https" {
  security_group_id = openstack_networking_secgroup_v2.lb.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "lb_ssh" {
  security_group_id = openstack_networking_secgroup_v2.lb.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.ssh_source_cidr
}

resource "openstack_networking_secgroup_rule_v2" "lb_icmp" {
  security_group_id = openstack_networking_secgroup_v2.lb.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = var.ssh_source_cidr
}

resource "openstack_networking_secgroup_v2" "frontend" {
  name        = "sg-frontend"
  description = "Web tier: HTTP from the load balancer, SSH from the bastion"
}

resource "openstack_networking_secgroup_rule_v2" "frontend_http" {
  security_group_id = openstack_networking_secgroup_v2.frontend.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_group_id   = openstack_networking_secgroup_v2.lb.id
}

resource "openstack_networking_secgroup_rule_v2" "frontend_ssh" {
  security_group_id = openstack_networking_secgroup_v2.frontend.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.lb.id
}

resource "openstack_networking_secgroup_rule_v2" "frontend_icmp" {
  security_group_id = openstack_networking_secgroup_v2.frontend.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = openstack_networking_subnet_v2.private.cidr
}

resource "openstack_networking_secgroup_v2" "db" {
  name        = "sg-db"
  description = "Database tier: MySQL from the frontends, SSH from the bastion"
}

resource "openstack_networking_secgroup_rule_v2" "db_mysql" {
  security_group_id = openstack_networking_secgroup_v2.db.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3306
  port_range_max    = 3306
  remote_group_id   = openstack_networking_secgroup_v2.frontend.id
}

resource "openstack_networking_secgroup_rule_v2" "db_ssh" {
  security_group_id = openstack_networking_secgroup_v2.db.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.lb.id
}

resource "openstack_networking_secgroup_rule_v2" "db_icmp" {
  security_group_id = openstack_networking_secgroup_v2.db.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = openstack_networking_subnet_v2.private.cidr
}

resource "openstack_networking_secgroup_v2" "nfs" {
  name        = "sg-nfs"
  description = "Storage tier: NFS from the frontends, SSH from the bastion"
}

locals {
  nfs_ports = {
    rpcbind_tcp = { protocol = "tcp", port = 111 }
    rpcbind_udp = { protocol = "udp", port = 111 }
    nfsd_tcp    = { protocol = "tcp", port = 2049 }
    nfsd_udp    = { protocol = "udp", port = 2049 }
  }
}

resource "openstack_networking_secgroup_rule_v2" "nfs_service" {
  for_each = local.nfs_ports

  security_group_id = openstack_networking_secgroup_v2.nfs.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = each.value.protocol
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_group_id   = openstack_networking_secgroup_v2.frontend.id
}

resource "openstack_networking_secgroup_rule_v2" "nfs_ssh" {
  security_group_id = openstack_networking_secgroup_v2.nfs.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.lb.id
}

resource "openstack_networking_secgroup_rule_v2" "nfs_icmp" {
  security_group_id = openstack_networking_secgroup_v2.nfs.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = openstack_networking_subnet_v2.private.cidr
}
