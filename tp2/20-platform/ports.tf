locals {
  network_id         = data.terraform_remote_state.infra.outputs.network_id
  subnet_id          = data.terraform_remote_state.infra.outputs.subnet_id
  subnet_cidr        = data.terraform_remote_state.infra.outputs.subnet_cidr
  security_group_ids = data.terraform_remote_state.infra.outputs.security_group_ids
  floating_ip        = data.terraform_remote_state.infra.outputs.floating_ip_address
}

resource "openstack_networking_port_v2" "lb" {
  name               = "port-lb"
  network_id         = local.network_id
  admin_state_up     = true
  security_group_ids = [local.security_group_ids["lb"]]

  fixed_ip {
    subnet_id  = local.subnet_id
    ip_address = var.lb_ip
  }
}

resource "openstack_networking_port_v2" "frontend" {
  count = var.frontend_count

  name               = "port-frontend-${count.index + 1}"
  network_id         = local.network_id
  admin_state_up     = true
  security_group_ids = [local.security_group_ids["frontend"]]

  fixed_ip {
    subnet_id  = local.subnet_id
    ip_address = var.frontend_ips[count.index]
  }
}

resource "openstack_networking_port_v2" "db" {
  name               = "port-db"
  network_id         = local.network_id
  admin_state_up     = true
  security_group_ids = [local.security_group_ids["db"]]

  fixed_ip {
    subnet_id  = local.subnet_id
    ip_address = var.db_ip
  }
}

resource "openstack_networking_port_v2" "nfs" {
  name               = "port-nfs"
  network_id         = local.network_id
  admin_state_up     = true
  security_group_ids = [local.security_group_ids["nfs"]]

  fixed_ip {
    subnet_id  = local.subnet_id
    ip_address = var.nfs_ip
  }
}

resource "openstack_networking_floatingip_associate_v2" "lb" {
  floating_ip = local.floating_ip
  port_id     = openstack_networking_port_v2.lb.id
}
