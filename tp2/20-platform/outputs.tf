output "site_url" {
  value = "http://${local.floating_ip}"
}

output "floating_ip" {
  value = local.floating_ip
}

output "private_addresses" {
  value = {
    lb       = var.lb_ip
    frontend = slice(var.frontend_ips, 0, var.frontend_count)
    db       = var.db_ip
    nfs      = var.nfs_ip
  }
}

output "ssh_config" {
  value = <<-EOT
    Host lb
        HostName ${local.floating_ip}
        User debian
        IdentityFile ~/.ssh/openstack1-mapaire.pem

    Host web-1 web-2 bdd nfs
        User debian
        IdentityFile ~/.ssh/openstack1-mapaire.pem
        ProxyJump lb
  EOT
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
