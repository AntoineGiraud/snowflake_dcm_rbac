--------------------------------------------------------------------------
-- 1. PREPARE WAREHOUSES & DATABASE
--------------------------------------------------------------------------
define warehouse BIKESHARE_LOADING_WH{{env_suffix}}
    warehouse_size = '{{wh_size}}' auto_suspend = 60 auto_resume = true;

define warehouse BIKESHARE_TRANSFORMING_WH{{env_suffix}}
    warehouse_size = '{{wh_size}}' auto_suspend = 60 auto_resume = true;

define warehouse BIKESHARE_READING_WH{{env_suffix}}
    warehouse_size = '{{wh_size}}' auto_suspend = 60 auto_resume = true;

define database BIKESHARE{{env_suffix}};

--------------------------------------------------------------------------
-- 2. PREPARE GLOBAL ROLES (ADMIN, LOADER, TRANSFORMER, READER)
--------------------------------------------------------------------------
define role BIKESHARE_ADMIN{{env_suffix}};
define role BIKESHARE_LOADER{{env_suffix}};
define role BIKESHARE_TRANSFORMER{{env_suffix}};
define role BIKESHARE_READER{{env_suffix}};

-- Hiérarchie globale
grant role BIKESHARE_ADMIN{{env_suffix}} to role {{project_owner_role}};
grant role BIKESHARE_LOADER{{env_suffix}} to role BIKESHARE_ADMIN{{env_suffix}};
grant role BIKESHARE_TRANSFORMER{{env_suffix}} to role BIKESHARE_ADMIN{{env_suffix}};
grant role BIKESHARE_READER{{env_suffix}} to role BIKESHARE_TRANSFORMER{{env_suffix}};

-- Accès globaux à la base de données
grant usage on database BIKESHARE{{env_suffix}} to role BIKESHARE_LOADER{{env_suffix}};
grant usage on database BIKESHARE{{env_suffix}} to role BIKESHARE_READER{{env_suffix}};

-- Accès globaux aux warehouses
grant usage on warehouse BIKESHARE_LOADING_WH{{env_suffix}} to role BIKESHARE_LOADER{{env_suffix}};
grant usage on warehouse BIKESHARE_TRANSFORMING_WH{{env_suffix}} to role BIKESHARE_TRANSFORMER{{env_suffix}};
grant usage on warehouse BIKESHARE_READING_WH{{env_suffix}} to role BIKESHARE_READER{{env_suffix}};

--------------------------------------------------------------------------
-- 3. PREPARE SOURCE SCHEMAS (System-aligned)
--------------------------------------------------------------------------
{% for src in sources %}
    {% set src_name = src.name | upper %}

    -- Création des couches Raw et Staging pour le système source
    define schema BIKESHARE{{env_suffix}}.BRONZE_{{src_name}} comment = '🚲🥉 {{src_name}} raw data';
    define schema BIKESHARE{{env_suffix}}.SILVER_{{src_name}} comment = '🚲🥈 {{src_name}} staging (normalized/typed)';

    -- Appel de la macro source
    {{ setup_source_layer(src_name) }}

{% endfor %}

--------------------------------------------------------------------------
-- 4. PREPARE TEAM SCHEMAS (Domain-aligned & Manual Inputs)
--------------------------------------------------------------------------
{% for team in teams %}
    {% set team_name = team.name | upper %}

    -- Création des Manual Inputs spécifiques à l'équipe
    define schema BIKESHARE{{env_suffix}}.BRONZE_MI_{{team_name}} comment = '🚲🥉 Manual inputs raw for {{team_name}}';
    define schema BIKESHARE{{env_suffix}}.SILVER_MI_{{team_name}} comment = '🚲🥈 Manual inputs staging for {{team_name}}';

    -- Création des couches métier de l'équipe
    define schema BIKESHARE{{env_suffix}}.SILVER_{{team_name}} comment = '🚲🥈 Intermediate/Integration data for {{team_name}}';
    define schema BIKESHARE{{env_suffix}}.GOLD_{{team_name}}   comment = '🚲🥇 Datamart (dim/fct) for {{team_name}}';

    -- Appel de la macro équipe
    {{ setup_team_layer(team_name) }}

{% endfor %}