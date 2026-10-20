# Version Ansible

Reconstruction complète de l'architecture WordPress répartie avec Ansible.
Contrairement à un usage courant de l'outil, Ansible ne se limite pas ici à la
configuration des machines : il crée également les ressources OpenStack, par
l'intermédiaire de la collection `openstack.cloud`.

```
Internet → IP flottante → HAProxy → web-1 / web-2 → bdd  (MariaDB)
                                                  → nfs  (médias partagés)
```

## Organisation

| Fichier | Rôle |
| --- | --- |
| `provision.yml` | crée réseau, sous-réseau, routeur, groupes de sécurité, instances et IP flottante |
| `site.yml` | configure les quatre étages dans l'ordre de leurs dépendances |
| `teardown.yml` | démonte l'ensemble, derrière une confirmation explicite |
| `group_vars/all.yml` | description unique de la pile : adresses, noms, règles de filtrage |
| `roles/` | `name_resolution`, `nfs_server`, `database`, `wordpress`, `loadbalancer` |

`provision.yml` écrit `inventory/hosts.ini` à partir des adresses qu'il vient
d'allouer. L'inventaire est donc un produit de l'exécution plutôt qu'un
fichier tenu à la main. Les hôtes privés y reçoivent le répartiteur comme
machine de rebond, seule voie d'accès possible avec une unique adresse
publique.

La description reste centralisée. HAProxy construit sa liste de backends à
partir du groupe `web`, et le droit d'accès MariaDB dérive du CIDR du
sous-réseau. Ajouter un frontend se résume à une entrée dans `instances`.

## Ce qui distingue cette version de la version Terraform

Terraform conserve un état et calcule un écart par rapport à lui. Ansible ne
procède pas ainsi : chaque module réconcilie la ressource vivante avec sa
description au moment de l'exécution, sans mémoire des passages précédents.
Une ressource supprimée en dehors du playbook sera simplement recréée, sans
qu'aucune dérive ne soit signalée.

La conséquence pratique porte sur la destruction. `terraform destroy` sait
exactement ce qu'il possède, là où `teardown.yml` supprime ce que
`group_vars/all.yml` désigne. Renommer une ressource dans ce fichier revient
donc à l'abandonner plutôt qu'à la détruire.

En échange, la configuration cesse d'être figée au premier démarrage. La
version Terraform s'appuie sur cloud-init, exécuté une seule fois : y modifier
`haproxy.cfg` impose de recréer la machine. Ici, `site.yml` se rejoue à
volonté et reconfigure des serveurs déjà en production.

## Prérequis

```bash
sudo pacman -S ansible python-openstacksdk
ansible-galaxy collection install -r requirements.yml
```

Ces ressources doivent préexister dans le projet. Les playbooks se contentent
de les rechercher.

| Ressource | Valeur par défaut | Variable |
| --- | --- | --- |
| Réseau externe | `provider-net` | `external_network` |
| Image | `debian-12` | `image_name` |
| Gabarit | `m1.small` | `flavor_name` |
| Paire de clés | `mapaire` | `keypair_name` |

Tout le reste est créé par `provision.yml`.

## Mise en œuvre

```bash
source ../jvilardell-openrc.sh

ansible-playbook provision.yml
ansible-playbook site.yml
```

Les playbooks lisent les mêmes variables d'environnement `OS_*` que le client
OpenStack, par l'intermédiaire d'openstacksdk. `provision.yml` affiche
l'adresse publique en fin d'exécution. WordPress présente ensuite son
assistant d'installation à la première visite.

Appliquer une modification de configuration consiste à rejouer `site.yml`, au
besoin restreint à un étage :

```bash
ansible-playbook site.yml --limit loadbalancer
```

## Difficulté rencontrée : l'absence de résolution DNS

Le premier déploiement a échoué sur un message trompeur :
`No package matching 'haproxy' is available`. Le paquet figure pourtant dans
Debian 12 et les machines disposaient de 18 Go libres.

Les mesures ont écarté les hypothèses successivement. Le trafic sortant
fonctionne, une connexion TCP vers l'adresse du CDN Debian aboutissant sans
difficulté. En revanche aucune résolution de nom n'était possible : le
résolveur de Neutron répond `REFUSED`, et les serveurs publics déclarés par le
cloud, `8.8.8.8` et `8.8.4.4`, se révèlent injoignables sur l'ensemble des
ports, tout comme la passerelle externe. La démonstration a tenu en une ligne,
une entrée ajoutée manuellement dans `/etc/hosts` suffisant à rendre les
dépôts accessibles.

Deux correctifs en découlent. Le rôle `name_resolution` résout les noms requis
depuis le poste d'administration, qui dispose lui d'un DNS opérationnel, puis
fige ces adresses dans le `/etc/hosts` de chaque instance avant toute
installation. Le rafraîchissement du cache APT a par ailleurs dû être rendu
inconditionnel, `cache_valid_time` tenant pour valide le cache vide laissé par
l'échec du premier démarrage.

Il s'agit d'un contournement, assumé comme tel. Les adresses figées se
périmeront le jour où ces CDN changeront de numérotation. La solution pérenne
consiste à obtenir un résolveur joignable auprès de l'exploitant du cloud.

## Destruction

```bash
ansible-playbook teardown.yml -e confirm=yes
```

La confirmation est délibérée. Le playbook supprime les instances avec leurs
disques éphémères, rend l'adresse flottante au pool partagé et détruit le
réseau. Rien de tout cela ne se rattrape.

## Secrets

Le mot de passe de la base ainsi que les huit clés de salage WordPress sont
générés sur le poste d'administration au premier passage, puis conservés dans
`.secrets/`, répertoire non versionné.

Ce cache remplit une fonction précise : il garantit des clés de salage
identiques sur les deux frontends d'une exécution à l'autre. Les régénérer
invaliderait toutes les sessions ouvertes et produirait un `wp-config.php` en
désaccord avec l'utilisateur déjà créé en base.

## Limites connues

Le stockage est éphémère, la base et l'export NFS résidant sur les disques des
instances. Le répartiteur constitue un point unique de défaillance, faute
d'une seconde adresse publique. Le service est rendu en HTTP seul, sans
terminaison TLS.
