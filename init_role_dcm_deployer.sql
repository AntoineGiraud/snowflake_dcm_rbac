-- ============================================================================
-- init.sql — Bootstrap du compte Snowflake pour le projet DCM "BONCO_INFRA"
-- ----------------------------------------------------------------------------
-- À jouer UNE SEULE FOIS, en ACCOUNTADMIN, avant le premier `snow dcm create`.
-- Crée un rôle de déploiement dédié (DCM_DEPLOYER) portant uniquement les
-- privilèges nécessaires à ce projet, et prépare le schéma qui hébergera
-- l'objet DCM_PROJECT (infra.rbac_dcm).
--
-- Périmètre volontairement réduit : create database / schema / warehouse / role
-- + manage grants. AUCUN grant create table/view : la création des objets de
-- données reste à dbt (cf. README §2).
-- ============================================================================

USE ROLE ACCOUNTADMIN;

--------------------------------------------------------------------------
-- 1. Rôle de déploiement dédié (owner des objets DCM_PROJECT)
--------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS DCM_DEPLOYER
    COMMENT = 'Rôle dédié au déploiement de projets DCM (RBAC + infra)';

--------------------------------------------------------------------------
-- 2. Privilèges niveau compte requis par la DDL du projet
--    (audit de sources/definitions/setup.sql + macros)
--------------------------------------------------------------------------
GRANT CREATE DATABASE  ON ACCOUNT TO ROLE DCM_DEPLOYER;   -- define database BONCO
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE DCM_DEPLOYER;   -- define warehouse *_WH (x3)
GRANT CREATE ROLE      ON ACCOUNT TO ROLE DCM_DEPLOYER;   -- define role * (globaux + par équipe)

-- MANAGE GRANTS : requis pour `grant ownership ... revoke current grants`
-- et pour les `grant select on future <objets>` sur des schémas dont la
-- propriété a été transférée à LOADER/TRANSFORMER.
-- ⚠️ C'est le SEUL privilège large ici (porte sur tout le compte) : il est
-- isolé sur ce rôle dédié, pas sur SYSADMIN, donc révocable d'un bloc.
GRANT MANAGE GRANTS    ON ACCOUNT TO ROLE DCM_DEPLOYER;

--------------------------------------------------------------------------
-- 3. Schéma hôte de l'objet DCM_PROJECT (cf. manifest: infra.rbac_dcm.*)
--------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS infra
    COMMENT = 'Objets transverses (DCM projects, métadonnées infra)';
CREATE SCHEMA   IF NOT EXISTS infra.rbac_dcm
    COMMENT = '🚲 Hôte des objets DCM_PROJECT (BONCO_INFRA_DEV / _PROD)';

--------------------------------------------------------------------------
-- 4. Droits du déployeur sur ce schéma
--------------------------------------------------------------------------
GRANT USAGE              ON DATABASE infra          TO ROLE DCM_DEPLOYER;
GRANT USAGE              ON SCHEMA   infra.rbac_dcm  TO ROLE DCM_DEPLOYER;
GRANT CREATE DCM PROJECT ON SCHEMA   infra.rbac_dcm  TO ROLE DCM_DEPLOYER;  -- create/own le projet
GRANT CREATE STAGE       ON SCHEMA   infra.rbac_dcm  TO ROLE DCM_DEPLOYER;  -- stage temporaire (upload défs via snow CLI)

--------------------------------------------------------------------------
-- 5. Attribution du rôle
--------------------------------------------------------------------------
-- À l'utilisateur qui lancera les déploiements (remplace ou garde CURRENT_USER) :
SET deployer_user = CURRENT_USER();
GRANT ROLE DCM_DEPLOYER TO USER IDENTIFIER($deployer_user);

-- Visibilité/contrôle pour SYSADMIN (optionnel mais conseillé : SYSADMIN
-- garde la main sur l'objet projet sans porter lui-même les privilèges sensibles).
GRANT ROLE DCM_DEPLOYER TO ROLE SYSADMIN;

--------------------------------------------------------------------------
-- Vérification rapide
--------------------------------------------------------------------------
SHOW GRANTS TO ROLE DCM_DEPLOYER;

-- ============================================================================
-- APRÈS ce script :
--   2. snow dcm create BONCO_INFRA --if-not-exists --target DEV
--   3. snow dcm plan   --target DEV     (lire le diff !)
--   4. snow dcm deploy --target DEV
--
-- Durcissement PROD (plus tard, hors périmètre "simple") :
--   - un rôle déployeur distinct par env (DCM_DEPLOYER_PROD) ;
--   - restreindre MANAGE GRANTS via des rôles plus ciblés si Snowflake
--     le permet sur ta version.
-- ============================================================================
