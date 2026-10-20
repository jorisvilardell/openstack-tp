output "network_id" {
  value = openstack_networking_network_v2.private.id
}

output "subnet_id" {
  value = openstack_networking_subnet_v2.private.id
}

output "subnet_cidr" {
  value = openstack_networking_subnet_v2.private.cidr
}

output "router_id" {
  value = openstack_networking_router_v2.main.id
}

output "security_group_ids" {
  value = {
    lb       = openstack_networking_secgroup_v2.lb.id
    frontend = openstack_networking_secgroup_v2.frontend.id
    db       = openstack_networking_secgroup_v2.db.id
    nfs      = openstack_networking_secgroup_v2.nfs.id
  }
}

output "floating_ip_address" {
  value = openstack_networking_floatingip_v2.lb.address
}
