# Version Heat

Déploiement de la même architecture WordPress répartie, cette fois décrit
comme une stack Heat. L'orchestrateur est ici celui d'OpenStack lui-même, et
non un outil tiers interrogeant son API.

```
Internet → IP flottante → HAProxy → web-0 / web-1 → bdd  (MariaDB)
                                                  → nfs  (médias partagés)
```

## Organisation

| Fichier | Rôle |
| --- | --- |
| `stack.yaml` | gabarit principal, décrit le réseau, le cloisonnement, la base, le stockage et le répartiteur |
| `web_node.yaml` | gabarit imbriqué, décrit un frontend, instancié autant de fois que demandé |
| `environment.yaml` | valeurs propres à ce cloud |

Le nombre de frontends est un paramètre. `web_count` pilote un
`OS::Heat::ResourceGroup` qui instancie `web_node.yaml` autant de fois que
nécessaire, sans qu'aucune autre ligne ne change. Passer de deux à quatre
serveurs web relève d'une mise à jour de la stack.

## Ce que Heat apporte par rapport aux deux autres versions

L'ordre de création n'est jamais déclaré. Heat le déduit du graphe des
dépendances que forment les `get_attr` et les `get_resource`. Le gabarit
exprime que le répartiteur a besoin des adresses des frontends, que ceux-ci
ont besoin de l'adresse de la base et de celle de l'adresse flottante, et
l'orchestrateur en tire seul la séquence correcte. Là où Terraform exigeait
des `depends_on` explicites et Ansible un ordre de plays, la contrainte
s'exprime ici par la donnée elle-même.

Les adresses privées ne sont d'ailleurs plus figées. Chaque port se voit
attribuer une adresse par Neutron, et les gabarits la récupèrent par
`get_attr`. La liste des backends HAProxy est construite avec une fonction
`repeat` sur les sorties du `ResourceGroup`, ce qui la rend automatiquement
cohérente avec `web_count`.

L'état, enfin, est tenu par le cloud et non par un fichier local. La stack est
une ressource OpenStack à part entière, consultable et supprimable par
n'importe quel membre du projet, sans partage préalable d'un `.tfstate`.

## Prérequis

Ces ressources doivent préexister dans le projet.

| Ressource | Valeur par défaut | Paramètre |
| --- | --- | --- |
| Réseau externe | `provider-net` | `external_network` |
| Image | `debian-12` | `image` |
| Gabarit | `m1.small` | `flavor` |
| Paire de clés | `mapaire` | `key_name` |

Le réseau tenant, son sous-réseau, le routeur, les quatre groupes de sécurité
et les cinq instances sont créés par la stack.

Le sous-réseau par défaut est `192.168.20.0/24`, distinct de celui des deux
autres versions. Les trois peuvent ainsi coexister si le quota le permet, les
noms de ressources étant par ailleurs préfixés par le nom de la stack.

## Mise en œuvre

```bash
source ../jvilardell-openrc.sh

openstack stack create -e environment.yaml -t stack.yaml wordpress
openstack stack show wordpress -c stack_status
openstack stack output show wordpress site_url
```

Le déploiement est asynchrone. Pour suivre son déroulement :

```bash
openstack stack event list wordpress --follow
```

Passer à quatre frontends, sans rien recréer d'autre :

```bash
openstack stack update -e environment.yaml -t stack.yaml \
  --parameter web_count=4 wordpress
```

## Suppression

```bash
openstack stack delete --yes --wait wordpress
```

**Opération irréversible.** Heat supprime l'ensemble de ce qu'il a créé, dans
l'ordre inverse des dépendances, y compris les disques des instances. La base
WordPress et les médias déposés disparaissent avec elles.

C'est le point fort de l'approche. Contrairement à la version Ansible, où la
destruction repose sur une liste de noms tenue à jour à la main, Heat connaît
exactement les ressources qu'il possède et n'en oublie aucune.

## La résolution DNS

Ce cloud ne met aucun résolveur à disposition du réseau tenant. Le paramètre
`extra_hosts` porte donc les correspondances nécessaires à l'installation, et
cloud-init les écrit dans `/etc/hosts` avant la première commande APT.

Ces adresses se périmeront le jour où les CDN concernés changeront de
numérotation. La solution pérenne reste d'obtenir un résolveur joignable
auprès de l'exploitant du cloud, après quoi le paramètre pourra être vidé.

## Limites connues

Le mot de passe de la base figure dans les sorties de la stack, lisibles par
`openstack stack output show`. C'est acceptable dans le cadre de cet exercice,
pas sur un déploiement réel, où ce secret devrait passer par Barbican.

Le stockage reste éphémère, le répartiteur demeure un point unique de
défaillance, et le service est rendu en HTTP seul. Ces trois limites sont
communes aux trois versions.
