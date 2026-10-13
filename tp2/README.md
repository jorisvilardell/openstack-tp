# TP2 — WordPress load-balanced on OpenStack

Terraform configuration for a five-instance WordPress stack:

```
Internet -> Floating IP -> HAProxy -> web-1 / web-2 -> bdd (MariaDB)
                                                    -> nfs (wp-content/uploads)
```

Only the load balancer holds a floating IP. The other four instances sit on
the tenant network and reach the internet outbound through the existing
router. SSH to them goes through the balancer, which doubles as a bastion.

## Prerequisites

The configuration assumes these already exist and does not manage them:

| Resource | Default name | Variable |
| --- | --- | --- |
| Tenant network | `lemien` | `private_network_name` |
| External network | `public` | `external_network_name` |
| Image | `debian-12` | `image_name` |
| Flavor | `m1.small` | `flavor_name` |
| Keypair | `mapaire` | `keypair_name` |

A router between the tenant network and the external network must be in place.
`terraform destroy` therefore never touches the network, the subnet, the router
or the keypair.

## Before the first apply

Check these on the remote cloud, in this order:

1. **Quota.** Five `m1.small` instances need 5 vCPU, 10 GB RAM and 100 GB of
   disk. Run `openstack limits show --absolute`.
2. **Address range.** The fixed addresses (`.11`, `.21`, `.22`, `.31`, `.41`)
   must fall inside the subnet allocation pool and be free. Run
   `openstack subnet show <subnet> -c cidr -c allocation_pools` and
   `openstack port list --network lemien`.
3. **DNS.** An empty `dns_nameservers` on the subnet means cloud-init cannot
   resolve the Debian mirrors and every instance boots without its packages.
4. **External network name.** `openstack network list --external` — the
   default here is `public`.
5. **Floating IP.** The tenant is limited to a small number. Release any
   unattached one with `openstack floating ip list --status DOWN` before
   applying.

## Usage

```bash
source ~/path/to/projet-openrc.sh
terraform init
terraform plan
terraform apply
```

Then follow the outputs:

```bash
terraform output site_url
terraform output -raw ssh_config >> ~/.ssh/config
```

WordPress serves its installation wizard on first visit. The database, the
user and the shared upload mount are already in place.

## Addresses

Addresses are pinned in `variables.tf` rather than left to DHCP, because the
HAProxy backend list, the MariaDB grant and the NFS export are all rendered
from the same values at plan time. Changing the subnet means changing those
variables together.

## Known limitations

- **Storage is ephemeral.** The database and the NFS export live on the
  instances' ephemeral disks. `terraform destroy`, or an instance rebuild,
  loses the content. Moving `bdd` and `nfs` to Cinder volumes is the next
  step if the data has to survive.
- **The balancer is a single point of failure.** One floating IP means no
  second balancer and no VRRP.
- **HTTP only.** No TLS termination on HAProxy yet; `WP_HOME` is pinned to
  `http://<floating-ip>`.
- **The MariaDB grant pattern assumes a /24** tenant subnet.
