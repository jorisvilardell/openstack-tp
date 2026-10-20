# Déploiement d'une architecture WordPress répartie sur OpenStack

Travaux pratiques d'infrastructure as code. Une même architecture à cinq
machines est déployée deux fois, d'abord avec Terraform puis avec Ansible,
afin de confronter les deux approches sur un cas identique plutôt que sur des
exemples théoriques.

![Topologie réseau](tp2/docs/network-topology.png)

## L'architecture

Un site WordPress est servi par deux frontends identiques, placés derrière un
répartiteur de charge HAProxy. Les deux nœuds partagent leur état par deux
canaux distincts : la base MariaDB pour le contenu rédactionnel, un export NFS
monté sur `wp-content/uploads` pour les fichiers déposés par les auteurs.

```
Internet → IP flottante → HAProxy → web-1 / web-2 → bdd  (MariaDB)
                                                  → nfs  (médias partagés)
```

Cette séparation est ce qui rend la répartition possible. Sans base commune,
chaque frontend servirait son propre site ; sans stockage partagé, une image
téléversée via `web-1` deviendrait invisible dès que la requête suivante
atterrirait sur `web-2`.

Le projet ne dispose que d'une seule adresse publique. Elle est donc attribuée
au répartiteur, seul exposé ; les quatre autres machines restent sur le réseau
privé et sortent par le routeur en NAT. L'administration des nœuds internes
passe par un rebond SSH sur le répartiteur, qui tient de fait le rôle de
bastion.

Le cloisonnement suit la même logique, étage par étage. Le groupe de sécurité
du répartiteur ouvre les ports 80 et 443 à tous ; celui des frontends
n'accepte le port 80 que depuis le répartiteur ; MariaDB n'écoute que pour les
frontends ; l'export NFS également. Chaque règle désigne le groupe émetteur
plutôt qu'une plage d'adresses, de sorte qu'ajouter un frontend n'oblige pas à
rouvrir quoi que ce soit.

## Les deux implémentations

| Répertoire | Outil | Contenu |
| --- | --- | --- |
| [`tp2/`](tp2/) | Terraform | infrastructure en deux couches, configuration par cloud-init |
| [`tp2-2/`](tp2-2/) | Ansible | provisionnement et configuration dans le même outil |

### tp2 — Terraform

Le code est scindé en deux racines possédant chacune son état. `10-infra`
porte ce qui dure : réseau, sous-réseau, routeur, groupes de sécurité, adresse
flottante. `20-platform` porte ce qui se jette : ports, instances,
provisionnement initial. La couche haute lit la couche basse par
`terraform_remote_state`.

Le bénéfice est concret. Détruire les machines pour les reconstruire ne rend
pas l'adresse publique au pool partagé, ce qui compte lorsque le quota n'en
accorde qu'une. La contrepartie est une discipline d'exécution : on applique
de bas en haut, on détruit dans l'ordre inverse.

La configuration des services repose sur cloud-init, exécuté une seule fois au
premier démarrage. Modifier la configuration d'HAProxy suppose donc de
recréer la machine.

### tp2-2 — Ansible

La même architecture est reconstruite intégralement avec Ansible, y compris la
création des ressources OpenStack via la collection `openstack.cloud`.
`provision.yml` bâtit l'infrastructure et produit l'inventaire à partir des
adresses qu'il vient d'allouer ; `site.yml` configure les quatre étages dans
l'ordre de leurs dépendances ; `teardown.yml` démonte l'ensemble, derrière une
confirmation explicite.

L'écart le plus net avec Terraform tient à l'absence d'état. Chaque module
réconcilie la ressource vivante avec sa description au moment de l'exécution,
sans mémoire de ce qui a été créé auparavant. Une ressource supprimée en
dehors du playbook est recréée au passage suivant, sans qu'aucune dérive ne
soit signalée. En revanche, la configuration cesse d'être figée au premier
démarrage : `site.yml` se rejoue à volonté et reconfigure des machines déjà en
service.

## Difficulté rencontrée : l'absence de résolution DNS

Le déploiement Ansible a d'abord échoué sur un message trompeur :
`No package matching 'haproxy' is available`. Le paquet existe pourtant dans
Debian 12 et la machine disposait de 18 Go libres.

La mesure a écarté les hypothèses une à une. Le trafic sortant fonctionne —
une connexion TCP vers l'IP du CDN Debian aboutit — mais aucune résolution de
nom n'était possible : le résolveur de Neutron répond `REFUSED`, et les
serveurs publics déclarés par le cloud (`8.8.8.8`, `8.8.4.4`) sont
injoignables sur l'ensemble des ports, de même que la passerelle externe. La
démonstration a tenu en une ligne : une entrée ajoutée manuellement dans
`/etc/hosts` suffisait à rendre les dépôts accessibles.

Deux correctifs en découlent. Un rôle `name_resolution` résout les noms requis
depuis le poste d'administration, qui dispose lui d'un DNS opérationnel, et
fige ces adresses dans le `/etc/hosts` de chaque instance avant toute
installation. Le rafraîchissement du cache APT a par ailleurs dû être rendu
inconditionnel : `cache_valid_time` tenait pour valide le cache vide laissé
par l'échec du premier démarrage, et APT ne relisait donc jamais les dépôts.

Il s'agit d'un contournement, assumé comme tel. Les adresses figées se
périmeront le jour où ces CDN changeront de numérotation ; la solution
pérenne consiste à obtenir un résolveur joignable auprès de l'exploitant du
cloud.

## Mise en œuvre

Les deux versions revendiquent les mêmes noms de ressources et ne peuvent donc
pas coexister sur un même projet. Il faut démonter l'une avant de monter
l'autre.

```bash
source jvilardell-openrc.sh

# Version Terraform
cd tp2/10-infra && terraform init && terraform apply
cd ../20-platform && terraform init && terraform apply

# Version Ansible
cd tp2-2
ansible-galaxy collection install -r requirements.yml
ansible-playbook provision.yml
ansible-playbook site.yml
```

Chaque répertoire possède sa propre documentation, plus détaillée : prérequis,
variables, ordre de destruction et limites connues.

## Limites assumées

Le stockage reste éphémère : la base et les médias vivent sur les disques des
instances, qu'une destruction emporte. Le répartiteur constitue un point
unique de défaillance, faute d'une seconde adresse publique permettant une
bascule. Enfin, le service est rendu en HTTP seul, sans terminaison TLS.

Ces choix tiennent au cadre de l'exercice et au quota disponible, non à une
contrainte technique : des volumes Cinder pour les données et un certificat
sur le répartiteur constitueraient les deux prolongements naturels.
