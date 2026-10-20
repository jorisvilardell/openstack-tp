# TP2-2 — the same stack, driven by Ansible

Second version of the TP2 exercise. Same topology, same five instances, same
WordPress behind HAProxy, but Ansible both provisions the OpenStack resources
and configures the machines. TP2 stays in place; the two are independent and
must not run against the same project at the same time, since they would fight
over the same resource names.

```
Internet -> Floating IP -> HAProxy -> web-1 / web-2 -> bdd (MariaDB)
                                                    -> nfs (wp-content/uploads)
```

## Layout

| Path | Role |
| --- | --- |
| `provision.yml` | creates network, subnet, router, security groups, instances, floating IP |
| `site.yml` | configures the four tiers in dependency order |
| `teardown.yml` | removes everything it created |
| `group_vars/all.yml` | one description of the stack: addresses, names, security rules |
| `roles/` | `nfs_server`, `database`, `wordpress`, `loadbalancer` |

`provision.yml` writes `inventory/hosts.ini` from the addresses it just
allocated, so the inventory is a product of the run rather than something kept
by hand. Private hosts reach Ansible through the load balancer as jump host,
which is the only way in with a single public address.

## What differs from TP2

Terraform keeps a state file and computes a diff against it. Ansible does not:
each module reconciles the live resource with the description at run time. A
resource deleted outside the playbook is simply recreated on the next run, and
nothing warns that it had drifted.

The practical consequence is on teardown. `terraform destroy` knows exactly
what it owns; `teardown.yml` deletes what `group_vars/all.yml` names, so a
resource renamed in the variables file is orphaned rather than removed.

In exchange, configuration is no longer frozen at first boot. TP2 provisions
through cloud-init, which runs once: changing `haproxy.cfg` means rebuilding
the instance. Here, `site.yml` is re-runnable, and changing a template
reconfigures the running machine.

## Prerequisites

```bash
sudo pacman -S ansible python-openstacksdk
ansible-galaxy collection install -r requirements.yml
```

These must already exist in the project; the playbooks look them up:

| Resource | Default | Variable |
| --- | --- | --- |
| External network | `provider-net` | `external_network` |
| Image | `debian-12` | `image_name` |
| Flavor | `m1.small` | `flavor_name` |
| Keypair | `mapaire` | `keypair_name` |

Everything else is created by `provision.yml`.

## Usage

```bash
source ~/jvilardell-openrc.sh
cd tp2-2

ansible-playbook provision.yml
ansible-playbook site.yml
```

The playbooks read the same `OS_*` environment variables as the OpenStack
client, through openstacksdk. Then open `http://<floating-ip>`, which
`provision.yml` prints at the end, and WordPress serves its install wizard.

Re-running `site.yml` is the normal way to apply a configuration change:

```bash
ansible-playbook site.yml --limit loadbalancer
ansible-playbook site.yml --limit web
```

## Teardown

```bash
ansible-playbook teardown.yml -e confirm=yes
```

The guard is deliberate: the playbook deletes the instances with their
ephemeral disks, releases the floating IP to the shared pool and removes the
network. None of it can be undone.

## Secrets

The database password and the eight WordPress salts are generated on the
controller on first run and cached under `.secrets/`, untracked. The cache is
what keeps both frontends on identical salts across runs — regenerating them
would invalidate every live session. Back that directory up, or accept that a
fresh controller means fresh credentials and a `wp-config.php` that no longer
matches the existing database user.

## Known limitations

- **Storage is ephemeral.** The database and the NFS export live on the
  instances' disks. A teardown loses both.
- **The balancer is a single point of failure.** One floating IP means no
  second balancer.
- **HTTP only.** No TLS termination; `WP_HOME` is pinned to the floating IP.
- **The MariaDB grant pattern assumes a /24** tenant subnet.
