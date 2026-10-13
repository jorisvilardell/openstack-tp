# Ports are declared explicitly so each instance keeps a predictable address
# across rebuilds, and so security groups attach to the port rather than to
# the server.
resource "openstack_networking_port_v2" "lb" {
  name               = "port-lb"
  network_id         = data.openstack_networking_network_v2.private.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.lb.id]

  fixed_ip {
    subnet_id  = data.openstack_networking_subnet_v2.private.id
    ip_address = var.lb_ip
  }
}

resource "openstack_networking_port_v2" "frontend" {
  count = var.frontend_count

  name               = "port-frontend-${count.index + 1}"
  network_id         = data.openstack_networking_network_v2.private.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.frontend.id]

  fixed_ip {
    subnet_id  = data.openstack_networking_subnet_v2.private.id
    ip_address = var.frontend_ips[count.index]
  }
}

resource "openstack_networking_port_v2" "db" {
  name               = "port-db"
  network_id         = data.openstack_networking_network_v2.private.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.db.id]

  fixed_ip {
    subnet_id  = data.openstack_networking_subnet_v2.private.id
    ip_address = var.db_ip
  }
}

resource "openstack_networking_port_v2" "nfs" {
  name               = "port-nfs"
  network_id         = data.openstack_networking_network_v2.private.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.nfs.id]

  fixed_ip {
    subnet_id  = data.openstack_networking_subnet_v2.private.id
    ip_address = var.nfs_ip
  }
}

# The single public address of the stack. Every other instance reaches the
# internet through the existing router doing source NAT.
resource "openstack_networking_floatingip_v2" "lb" {
  pool        = var.external_network_name
  description = "Public entry point of the lemien stack"
}

resource "openstack_networking_floatingip_associate_v2" "lb" {
  floating_ip = openstack_networking_floatingip_v2.lb.address
  port_id     = openstack_networking_port_v2.lb.id
}
