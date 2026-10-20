# Déploiement d'une architecture WordPress répartie sur OpenStack

Travaux pratiques d'infrastructure as code. Une même architecture à cinq
machines est déployée deux fois, avec deux outils différents, afin de les
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

## Les deux versions

| Répertoire | Outil | Documentation |
| --- | --- | --- |
| [`tp-terraform/`](tp-terraform/) | Terraform | infrastructure en deux couches, services configurés par cloud-init |
| [`tp-ansible/`](tp-ansible/) | Ansible | provisionnement et configuration réunis dans un même outil |

Chaque répertoire contient son propre README : architecture détaillée,
prérequis, variables, mise en œuvre, difficultés rencontrées et limites.

Les deux versions revendiquent les mêmes noms de ressources et ne peuvent donc
pas coexister sur un même projet OpenStack. Il faut démonter l'une avant de
monter l'autre.
