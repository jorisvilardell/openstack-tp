locals {
  # Every tier accepts traffic from the tenant subnet only; the security
  # groups narrow that further, tier by tier.
  client_cidr = data.openstack_networking_subnet_v2.private.cidr

  # MariaDB grants take a host pattern, not CIDR notation. The tenant network
  # is a /24, so the first three octets plus a wildcard cover it exactly.
  db_client_host = "${join(".", slice(split(".", cidrhost(local.client_cidr, 0)), 0, 3))}.%"

  salts = { for name in local.wordpress_salt_names :
    "salt_${name}" => random_password.wordpress_salt[name].result
  }

  # Rendered into haproxy.cfg as the backend server list.
  haproxy_backends = join("\n", [
    for index, address in slice(var.frontend_ips, 0, var.frontend_count) :
    "          server web${index + 1} ${address}:80 check cookie web${index + 1}"
  ])

  frontend_user_data = templatefile("${path.module}/cloudinit/frontend.yaml.tftpl", merge(local.salts, {
    db_name        = var.db_name
    db_user        = var.db_user
    db_password    = random_password.db.result
    db_ip          = var.db_ip
    nfs_ip         = var.nfs_ip
    nfs_export     = var.nfs_export
    public_address = openstack_networking_floatingip_v2.lb.address
  }))
}

resource "openstack_compute_instance_v2" "db" {
  name            = "bdd"
  image_id        = data.openstack_images_image_v2.debian.id
  flavor_id       = data.openstack_compute_flavor_v2.default.id
  key_pair        = var.keypair_name
  config_drive    = true
  stop_before_destroy = true

  network {
    port = openstack_networking_port_v2.db.id
  }

  user_data = templatefile("${path.module}/cloudinit/db.yaml.tftpl", {
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = random_password.db.result
    db_ip       = var.db_ip
    client_cidr = local.db_client_host
  })
}

resource "openstack_compute_instance_v2" "nfs" {
  name            = "nfs"
  image_id        = data.openstack_images_image_v2.debian.id
  flavor_id       = data.openstack_compute_flavor_v2.default.id
  key_pair        = var.keypair_name
  config_drive    = true
  stop_before_destroy = true

  network {
    port = openstack_networking_port_v2.nfs.id
  }

  user_data = templatefile("${path.module}/cloudinit/nfs.yaml.tftpl", {
    nfs_export  = var.nfs_export
    client_cidr = local.client_cidr
  })
}

# Frontends are created after the tiers they depend on. Their boot script
# still waits on the NFS port, because creation order does not guarantee the
# service inside the instance is ready.
resource "openstack_compute_instance_v2" "frontend" {
  count = var.frontend_count

  name         = "web-${count.index + 1}"
  image_id     = data.openstack_images_image_v2.debian.id
  flavor_id    = data.openstack_compute_flavor_v2.default.id
  key_pair     = var.keypair_name
  config_drive = true

  network {
    port = openstack_networking_port_v2.frontend[count.index].id
  }

  user_data = local.frontend_user_data

  depends_on = [
    openstack_compute_instance_v2.db,
    openstack_compute_instance_v2.nfs,
  ]
}

resource "openstack_compute_instance_v2" "lb" {
  name         = "lb"
  image_id     = data.openstack_images_image_v2.debian.id
  flavor_id    = data.openstack_compute_flavor_v2.default.id
  key_pair     = var.keypair_name
  config_drive = true

  network {
    port = openstack_networking_port_v2.lb.id
  }

  user_data = templatefile("${path.module}/cloudinit/lb.yaml.tftpl", {
    backend_servers = local.haproxy_backends
  })

  depends_on = [openstack_compute_instance_v2.frontend]
}
