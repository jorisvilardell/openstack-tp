resource "openstack_networking_network_v2" "private" {
  name           = var.private_network_name
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "private" {
  name            = "${var.private_network_name}-subnet"
  network_id      = openstack_networking_network_v2.private.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers

  allocation_pool {
    start = var.allocation_pool_start
    end   = var.allocation_pool_end
  }
}

resource "openstack_networking_router_v2" "main" {
  name                = var.router_name
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "private" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.private.id
}

resource "openstack_networking_floatingip_v2" "lb" {
  pool        = var.external_network_name
  description = "Public entry point of the lemien stack"
}
