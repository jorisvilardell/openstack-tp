# Version Terraform

Déploiement de l'architecture WordPress répartie à l'aide de Terraform, la
configuration des services étant confiée à cloud-init.

![Topologie réseau](docs/network-topology.png)

Vue Horizon de la pile déployée : le réseau externe `provider-net` à gauche,
le réseau tenant `lemien` à droite, reliés par le routeur `lemienroux` qui
porte la passerelle `192.168.10.1`.

## Organisation en deux couches

Le code est scindé en deux racines, chacune dotée de son propre état.

| Couche | Ressources | Rythme de vie |
| --- | --- | --- |
| `10-infra/` | réseau, sous-réseau, routeur, groupes de sécurité, IP flottante | stable |
| `20-platform/` | ports, instances, provisionnement cloud-init | reconstruit librement |

`20-platform` lit la couche inférieure par `terraform_remote_state`, pointé sur
`../10-infra/terraform.tfstate`. La dépendance est strictement à sens unique.

Ce découpage suit la durée de vie des ressources plutôt que leur nature. Il
permet de détruire et reconstruire les machines sans rendre l'adresse publique
au pool partagé, ce qui compte lorsque le quota n'en accorde qu'une seule. En
contrepartie, l'ordre d'exécution devient contraignant : on applique de bas en
haut, on détruit dans l'ordre inverse.

## Adressage

Les adresses des instances sont figées dans `variables.tf` plutôt que laissées
au DHCP : `.11` pour le répartiteur, `.21` et `.22` pour les frontends, `.31`
pour la base, `.41` pour le serveur NFS. La plage DHCP démarre à `.100`, de
sorte qu'aucune attribution automatique ne vienne entrer en collision avec un
port déclaré.

Ce choix n'est pas cosmétique : la liste des backends HAProxy, le droit
d'accès MariaDB et l'export NFS sont tous rendus à partir de ces mêmes
variables au moment du `plan`. La topologie n'est décrite qu'une fois.

## Prérequis

Ces ressources doivent préexister dans le projet ; la configuration se contente
de les rechercher.

| Ressource | Valeur par défaut | Variable |
| --- | --- | --- |
| Réseau externe | `provider-net` | `external_network_name` |
| Image | `debian-12` | `image_name` |
| Gabarit | `m1.small` | `flavor_name` |
| Paire de clés | `mapaire` | `keypair_name` |

Tout le reste est créé par Terraform, y compris le réseau tenant, son
sous-réseau et le routeur.

Le nom du réseau externe se renseigne dans `10-infra/terraform.tfvars`, fichier
non versionné dont `terraform.tfvars.example` donne le modèle.

## Vérifications préalables

Avant le premier `apply`, trois points méritent d'être contrôlés sur le cloud :

1. **Le quota.** Cinq instances `m1.small` réclament 5 vCPU, 10 Go de mémoire
   et 100 Go de disque. `openstack limits show --absolute`.
2. **Le nom du réseau externe.** `openstack network list --external`.
3. **Les adresses flottantes.** Le projet n'en obtient qu'un nombre réduit ;
   libérer celles qui ne servent plus avec
   `openstack floating ip list --status DOWN`.

## Mise en œuvre

```bash
source ../jvilardell-openrc.sh

cd 10-infra && terraform init && terraform apply
cd ../20-platform && terraform init && terraform apply
```

Les sorties fournissent l'URL du site ainsi qu'un bloc de configuration SSH
prêt à l'emploi :

```bash
terraform output site_url
terraform output -raw ssh_config >> ~/.ssh/config
```

WordPress présente son assistant d'installation à la première visite : la base,
l'utilisateur et le point de montage partagé sont déjà en place.

## Destruction

L'ordre s'inverse. Détruire `10-infra` alors que `20-platform` détient encore
des instances empêcherait la suppression du réseau et libérerait l'adresse
flottante.

```bash
cd 20-platform && terraform destroy
cd ../10-infra && terraform destroy
```

## Limites connues

Le stockage est éphémère : la base et l'export NFS résident sur les disques des
instances, qu'une destruction emporte. Les basculer sur des volumes Cinder
constituerait le prolongement naturel si les données devaient survivre.

Le répartiteur est un point unique de défaillance, faute d'une seconde adresse
publique autorisant une bascule. Le service est rendu en HTTP seul, sans
terminaison TLS, et `WP_HOME` est fixé sur l'adresse flottante.

Enfin, la configuration des services passe par cloud-init, qui ne s'exécute
qu'au premier démarrage : modifier `haproxy.cfg` impose de recréer la machine.
C'est précisément ce que la version Ansible lève.
