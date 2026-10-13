locals {
  frontend_inventory = join("\n", [
    for index, address in slice(var.frontend_ips, 0, var.frontend_count) :
    "web-${index + 1} ansible_host=${address}"
  ])

  ansible_inventory = <<-EOT
    [lb]
    lb ansible_host=${local.floating_ip}

    [web]
    ${local.frontend_inventory}

    [db]
    bdd ansible_host=${var.db_ip}

    [nfs]
    nfs ansible_host=${var.nfs_ip}

    [private:children]
    web
    db
    nfs

    [all:vars]
    ansible_user=debian
    ansible_ssh_private_key_file=${var.ssh_private_key}

    [private:vars]
    ansible_ssh_common_args=-o ProxyJump=debian@${local.floating_ip} -o StrictHostKeyChecking=accept-new
  EOT
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  content         = local.ansible_inventory
  file_permission = "0644"

  depends_on = [
    openstack_compute_instance_v2.lb,
    openstack_compute_instance_v2.frontend,
    openstack_compute_instance_v2.db,
    openstack_compute_instance_v2.nfs,
  ]
}
