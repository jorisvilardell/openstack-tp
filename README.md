# Déploiement d'une architecture WordPress répartie sur OpenStack

Travaux pratiques d'infrastructure as code. Une même architecture à cinq
machines est déployée trois fois, avec trois outils différents, afin de les
confronter sur un cas identique.

![Topologie réseau](tp-terraform/docs/network-topology.png)

```
Internet → IP flottante → HAProxy → web-1 / web-2 → bdd  (MariaDB)
                                                  → nfs  (médias partagés)
```

Deux frontends WordPress derrière un répartiteur de charge, partageant leur
contenu par une base commune et leurs fichiers par un export NFS. Une seule
adresse publique, attribuée au répartiteur. Les autres machines restent sur
le réseau privé et s'administrent par rebond SSH.

## Les trois versions

| Répertoire | Outil | Documentation |
| --- | --- | --- |
| [`tp-terraform/`](tp-terraform/) | Terraform | infrastructure en deux couches, services configurés par cloud-init |
| [`tp-ansible/`](tp-ansible/) | Ansible | provisionnement et configuration réunis dans un même outil |
| [`tp-heat/`](tp-heat/) | Heat | gabarit orchestré par OpenStack lui-même, nombre de frontends paramétrable |

Chaque répertoire contient son propre README : architecture détaillée,
prérequis, variables, mise en œuvre, difficultés rencontrées et limites.

Les versions Terraform et Ansible revendiquent les mêmes noms de ressources et
ne peuvent donc pas coexister sur un même projet OpenStack. La version Heat
préfixe les siens par le nom de la stack et travaille sur un autre
sous-réseau, ce qui la rend compatible avec les deux autres si le quota le
permet.
