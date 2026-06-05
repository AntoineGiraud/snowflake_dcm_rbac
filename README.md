# 🚲 BONCO — Infra & RBAC Snowflake (DCM)

Gestion déclarative de l'**infrastructure et des droits** Snowflake via **Snowflake DCM Projects**.
Le périmètre est volontairement restreint : **DCM gère le contenant, dbt gère le contenu.**

---

## Mes inspirations

- de snowflake
  - blog post [intro snowflake dcm](https://www.snowflake.com/en/blog/snowflake-dcm-projects-public-preview/)
  - [get started snowflake dcm](https://www.snowflake.com/en/developers/guides/get-started-snowflake-dcm-projects/?utm_campaign=Product&utm_content=1774386069&utm_medium=Snowflake%20Developers&utm_source=linkedin)
- mes projets github
  - [terraform snowflake](https://github.com/AntoineGiraud/terraform_snowflake)
  - [streamlit snowflake démo](https://github.com/AntoineGiraud/streamlit_snowflake_demo)
  - [dbt hypermarché](https://github.com/AntoineGiraud/dbt_hypermarche)

## 1. Qu'est-ce que Snowflake DCM ?

Un méli-mélo assumé de trois outils que tu connais déjà :

| Brique | Ce que DCM en reprend |
|--------|------------------------|
| **Terraform** | Approche **déclarative** : tu décris l'état voulu, Snowflake calcule le delta (`PLAN`) puis l'applique (`DEPLOY`). Pas de provider externe ni de state file à héberger : l'état vit dans Snowflake (objet `DCM_PROJECT`). |
| **Jinja** | **Templating** des définitions SQL (boucles `{% for %}`, variables `{{ }}`, macros) pour générer le RBAC par source et par équipe sans copier-coller. |
| **dbt** | La **logique de macros + variables d'environnement** (`env_suffix`, `targets` DEV/PROD), et la séparation des responsabilités par couche. |

> Feature en **public preview** : épingle ta version de Snowflake CLI, la syntaxe peut encore bouger.

### Le modèle déclaratif, en clair

À chaque `DEPLOY`, pour les objets **gérés par ce projet** :

| État de l'objet | Action |
|-----------------|--------|
| Défini, n'existe pas | `CREATE` |
| Défini, diffère du réel | `ALTER` |
| Défini, identique | skip |
| **Existe mais retiré du code** | **`DROP`** ⚠️ |

Retirer un objet du SQL = le supprimer au prochain deploy. C'est voulu. **Toujours lire le `PLAN` avant de `DEPLOY`** (voir §5).

---

## 2. Le parti pris : DCM pour le RBAC, dbt pour les tables

```
┌─────────────────────────── DCM (ce repo) ───────────────────────────┐
│  Stateless, rarement modifié                                          │
│  • Warehouses (LOADING / TRANSFORMING / READING)                      │
│  • Database BONCO                                                     │
│  • Schémas (les CONTENANTS : BRONZE_*, SILVER_*, GOLD_*)               │
│  • Rôles + hiérarchie + ownership                                     │
│  • GRANTs, dont les `grant ... on FUTURE` (la clé, voir §4)           │
└───────────────────────────────────────────────────────────────────────┘
                                  │
                  dbt crée tables/vues DANS ces schémas
                                  ▼
┌─────────────────────────── dbt (autre repo) ─────────────────────────┐
│  Stateful, modifié en continu                                         │
│  • TOUTES les tables, vues, dynamic tables                            │
│  • Modèles stg_, int_, fct_, dim_                                     │
└───────────────────────────────────────────────────────────────────────┘
```

**Pourquoi cette frontière ?** Le `DROP` de DCM porte sur l'objet déclaré. Si une table était sous DCM et qu'on la retirait du code, DCM la dropperait (perte de données). En laissant **toute création de table à dbt**, DCM ne gère que des objets quasi sans état : dropper un warehouse ou un rôle est sans danger, recréer un schéma vide aussi. Le risque destructif est neutralisé par construction.

⚠️ Seul objet DCM porteur de données indirectement : la **`DATABASE`** et les **schémas**. Ne jamais retirer un schéma du code tant qu'il contient des objets dbt vivants sans avoir lu le `PLAN`. Garder `DATA_RETENTION_TIME_IN_DAYS` > 0 (Time Travel) comme filet (`UNDROP`).

---

## 3. Rôles, warehouses & responsabilités

Trois warehouses, un par étage du flux de données :

| Warehouse | Rôle propriétaire d'usage | Qui s'en sert |
|-----------|---------------------------|---------------|
| `BONCO_LOADING_WH` | `BONCO_LOADER` | EL : ingestion brute (Fivetran, snowpipe, seeds) |
| `BONCO_TRANSFORMING_WH` | `BONCO_TRANSFORMER` | **dbt** (build des modèles) |
| `BONCO_READING_WH` | `BONCO_READER` + readers d'équipe | Consommation BI |

Hiérarchie des rôles (héritage descendant des droits de lecture) :

```
SYSADMIN
└── BONCO_ADMIN
    ├── BONCO_LOADER          → owner des schémas BRONZE_* (raw + manual inputs)
    └── BONCO_TRANSFORMER     → owner des schémas SILVER_* / GOLD_*  (dbt tourne ici)
        └── BONCO_READER      → SELECT global
            ├── BONCO_CORE_READER
            ├── BONCO_MARKETING_READER
            ├── BONCO_OPERATIONS_READER
            └── BONCO_FINANCE_READER   → SELECT cloisonné sur les schémas de l'équipe
```

---

## 4. Architecture des schémas (medallion)

Générée par boucle Jinja sur `sources` et `teams` ([sources/definitions/setup.sql](sources/definitions/setup.sql)).

### Par source système (`SAP`, `SF`)
| Schéma | Étage | Owner |
|--------|-------|-------|
| `BRONZE_<SRC>` | 🥉 Raw (données brutes ingérées telles quelles) | `LOADER` |
| `SILVER_<SRC>` | 🥈 Staging (normalisé / typé) | `TRANSFORMER` |

### Par équipe métier (`CORE`, `MARKETING`, `OPERATIONS`, `FINANCE`)
| Schéma | Étage | Owner |
|--------|-------|-------|
| `BRONZE_MI_<TEAM>` | 🥉 Manual inputs bruts | `LOADER` |
| `SILVER_MI_<TEAM>` | 🥈 Manual inputs staging | `TRANSFORMER` |
| `SILVER_<TEAM>` | 🥈 Intermediate / Integration (modèles `int_`) | `TRANSFORMER` |
| `GOLD_<TEAM>` | 🥇 Datamart : `fct_`, `dim_` | `TRANSFORMER` |

### La pièce maîtresse : les `grant ... on FUTURE`

Dans les deux macros, chaque schéma reçoit :
```sql
grant select on all    <objets> in schema ... to role <reader>;
grant select on future <objets> in schema ... to role <reader>;
```
C'est **le pont entre DCM et dbt** : DCM pré-accorde le `SELECT` sur les objets *futurs*. Quand dbt créera ensuite une table dans `GOLD_FINANCE`, le rôle `BONCO_FINANCE_READER` y aura accès **automatiquement**, sans nouveau deploy DCM. L'infra et le contenu restent découplés.

---

## 5. Commandes `snow dcm` utiles

> Toujours exécuter depuis le dossier contenant `manifest.yml`. La cible par défaut est `DEV` (`default_target` dans le manifest).

```bash
# Créer l'objet DCM_PROJECT côté Snowflake (une fois par environnement)
snow dcm create BONCO_INFRA --if-not-exists --target DEV
snow dcm create BONCO_INFRA --if-not-exists --target PROD

# 🔍 PLAN : dry-run, AUCUNE modif. À lire avant tout deploy.
snow dcm plan --target DEV
snow dcm plan --target PROD --save-output          # sauvegarde le diff
snow dcm plan --target DEV --variable "wh_size='XS'"   # override ponctuel

# 🚀 DEPLOY : applique le delta
snow dcm deploy --target DEV
snow dcm deploy --target PROD --alias 'release rbac v1'    # nomme le déploiement

# Inspection / nettoyage
snow dcm list
snow dcm describe BONCO_INFRA
snow dcm drop BONCO_INFRA            # supprime l'objet projet (pas géré en routine)
```

### Garde-fou recommandé en CI
1. Sur PR : `snow dcm plan --target PROD --save-output`, publier le diff en commentaire.
2. **Bloquer** le merge si le PLAN contient un `DROP DATABASE` ou `DROP SCHEMA` non approuvé (required reviewer / GitHub Environment protection).
3. Sur merge `main` : `snow dcm deploy --target PROD`.

---

## 6. Configuration (manifest.yml)

| Élément | Rôle |
|---------|------|
| `targets.DEV` / `targets.PROD` | Un objet `DCM_PROJECT` distinct par environnement, même compte. |
| `templating.defaults` | Valeurs partagées : `compagny`, `wh_size`, liste des `sources` et `teams`. |
| `templating.configurations.<ENV>.env_suffix` | `_DEV` en dev, `""` en prod : suffixe bases/warehouses/rôles pour isoler les environnements. |

Ajouter une source ou une équipe = **une ligne** dans `manifest.yml`, les schémas et grants se génèrent par boucle.

---

## 7. Points à trancher (cohérence de nommage)

Le code et la vision cible divergent légèrement. À aligner :

- **Schémas sources** : le code crée `BRONZE_SAP` / `SILVER_SAP`. Si tu veux exposer l'étage dans le nom (`BRONZE_RAW_SAP`, `SILVER_STG_SAP`), adapte le template. Recommandation : garder court (`BRONZE_<SRC>`) puisque l'étage est déjà porté par le préfixe medallion.
- **Couches équipe** : `SILVER_<TEAM>` joue le rôle de *silver intermediate*. Si tu préfères l'expliciter en `SILVER_INT_<TEAM>`, harmonise avec la convention `BRONZE_MI_` / `SILVER_MI_` déjà en place.
- Décider et figer **une seule** convention avant le premier deploy PROD (un renommage de schéma post-prod = drop/recreate = perte des objets dbt dedans).
