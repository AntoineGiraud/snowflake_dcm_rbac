--------------------------------------------------------------------------
-- 1. PREPARE WAREHOUSES & DATABASE
--------------------------------------------------------------------------
define warehouse {{compagny}}_LOADING_WH{{env_suffix}}
    warehouse_size = '{{wh_size}}' auto_suspend = 60 auto_resume = true;

define warehouse {{compagny}}_TRANSFORMING_WH{{env_suffix}}
    warehouse_size = '{{wh_size}}' auto_suspend = 60 auto_resume = true;

define warehouse {{compagny}}_READING_WH{{env_suffix}}
    warehouse_size = '{{wh_size}}' auto_suspend = 60 auto_resume = true;

define database {{compagny}}{{env_suffix}};

--------------------------------------------------------------------------
-- 2. PREPARE GLOBAL ROLES (ADMIN, LOADER, TRANSFORMER, READER)
--------------------------------------------------------------------------
define role {{compagny}}_ADMIN{{env_suffix}};
define role {{compagny}}_LOADER{{env_suffix}};
define role {{compagny}}_TRANSFORMER{{env_suffix}};
define role {{compagny}}_READER{{env_suffix}};

-- Hiérarchie globale
grant role {{compagny}}_ADMIN{{env_suffix}} to role {{project_owner_role}};
grant role {{compagny}}_LOADER{{env_suffix}} to role {{compagny}}_ADMIN{{env_suffix}};
grant role {{compagny}}_TRANSFORMER{{env_suffix}} to role {{compagny}}_ADMIN{{env_suffix}};
grant role {{compagny}}_READER{{env_suffix}} to role {{compagny}}_TRANSFORMER{{env_suffix}};

-- Accès globaux à la base de données
grant usage on database {{compagny}}{{env_suffix}} to role {{compagny}}_LOADER{{env_suffix}};
grant usage on database {{compagny}}{{env_suffix}} to role {{compagny}}_READER{{env_suffix}};

-- Accès globaux aux warehouses
grant usage on warehouse {{compagny}}_LOADING_WH{{env_suffix}} to role {{compagny}}_LOADER{{env_suffix}};
grant usage on warehouse {{compagny}}_TRANSFORMING_WH{{env_suffix}} to role {{compagny}}_TRANSFORMER{{env_suffix}};
grant usage on warehouse {{compagny}}_READING_WH{{env_suffix}} to role {{compagny}}_READER{{env_suffix}};

--------------------------------------------------------------------------
-- 3. PREPARE SOURCE SCHEMAS (System-aligned)
--------------------------------------------------------------------------
{% for src in sources %}
    {% set src_name = src.name | upper %}

    -- Création des couches Raw et Staging pour le système source
    define schema {{compagny}}{{env_suffix}}.BRONZE_{{src_name}} comment = '🚲🥉 {{src_name}} raw data';
    define schema {{compagny}}{{env_suffix}}.SILVER_{{src_name}} comment = '🚲🥈 {{src_name}} staging (normalized/typed)';

    -- Appel de la macro source
    {{ setup_source_layer(src_name) }}

{% endfor %}

--------------------------------------------------------------------------
-- 4. PREPARE TEAM SCHEMAS (Domain-aligned & Manual Inputs)
--------------------------------------------------------------------------
{% for team in teams %}
    {% set team_name = team.name | upper %}

    -- Création des Manual Inputs spécifiques à l'équipe
    define schema {{compagny}}{{env_suffix}}.BRONZE_MI_{{team_name}} comment = '🚲🥉 Manual inputs raw for {{team_name}}';
    define schema {{compagny}}{{env_suffix}}.SILVER_MI_{{team_name}} comment = '🚲🥈 Manual inputs staging for {{team_name}}';

    -- Création des couches métier de l'équipe
    define schema {{compagny}}{{env_suffix}}.SILVER_{{team_name}} comment = '🚲🥈 Intermediate/Integration data for {{team_name}}';
    define schema {{compagny}}{{env_suffix}}.GOLD_{{team_name}}   comment = '🚲🥇 Datamart (dim/fct) for {{team_name}}';

    -- Appel de la macro équipe
    {{ setup_team_layer(team_name) }}

{% endfor %}