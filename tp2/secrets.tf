resource "random_password" "db" {
  length  = 24
  special = false
}

locals {
  wordpress_salt_names = [
    "auth_key",
    "secure_auth_key",
    "logged_in_key",
    "nonce_key",
    "auth_salt",
    "secure_auth_salt",
    "logged_in_salt",
    "nonce_salt",
  ]
}

resource "random_password" "wordpress_salt" {
  for_each = toset(local.wordpress_salt_names)

  length           = 64
  special          = true
  override_special = "!@#%^&*()-_=+[]{}<>:?."
}
