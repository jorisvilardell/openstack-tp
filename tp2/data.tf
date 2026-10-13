data "openstack_images_image_v2" "debian" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "default" {
  name = var.flavor_name
}

data "openstack_networking_network_v2" "external" {
  name     = var.external_network_name
  external = true
}
