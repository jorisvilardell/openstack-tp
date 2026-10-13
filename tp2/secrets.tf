# Generated once and kept in the Terraform state, never in the repository.
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

# One salt per WordPress constant, shared by both frontends. The excluded
# characters are those that would terminate or escape the single-quoted PHP
# string the salt is written into.
resource "random_password" "wordpress_salt" {
  for_each = toset(local.wordpress_salt_names)

  length           = 64
  special          = true
  override_special = "!@#%^&*()-_=+[]{}<>:?."
}
