data "openstack_images_image_v2" "debian" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "default" {
  name = var.flavor_name
}

data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "${path.module}/../10-infra/terraform.tfstate"
  }
}
