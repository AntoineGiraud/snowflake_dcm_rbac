-- ==========================================
-- MACRO 2 : Pour les équipes métier (et leurs inputs manuels)
-- ==========================================
{% macro setup_team_layer(team_name) %}

    -- 1. Création du rôle reader de l'équipe
    define role BIKESHARE_{{team_name}}_READER{{env_suffix}} comment = '🚲 Reads {{team_name}} specific data';
    grant role BIKESHARE_{{team_name}}_READER{{env_suffix}} to role BIKESHARE_READER{{env_suffix}};

    -- 2. Propriété : Manual Inputs et Couches Métier
    grant ownership on schema BIKESHARE{{env_suffix}}.BRONZE_MI_{{team_name}} to role BIKESHARE_LOADER{{env_suffix}} revoke current grants;
    grant ownership on schema BIKESHARE{{env_suffix}}.SILVER_MI_{{team_name}} to role BIKESHARE_TRANSFORMER{{env_suffix}} revoke current grants;
    grant ownership on schema BIKESHARE{{env_suffix}}.SILVER_{{team_name}} to role BIKESHARE_TRANSFORMER{{env_suffix}} revoke current grants;
    grant ownership on schema BIKESHARE{{env_suffix}}.GOLD_{{team_name}} to role BIKESHARE_TRANSFORMER{{env_suffix}} revoke current grants;

    -- 3. Accès de base pour le rôle de l'équipe
    grant usage on database BIKESHARE{{env_suffix}} to role BIKESHARE_{{team_name}}_READER{{env_suffix}};
    grant usage on warehouse BIKESHARE_READING_WH{{env_suffix}} to role BIKESHARE_{{team_name}}_READER{{env_suffix}};

    -- 4. Droits de lecture sur les schémas de l'équipe
    {% set team_schemas = ['BRONZE_MI_' ~ team_name, 'SILVER_MI_' ~ team_name, 'SILVER_' ~ team_name, 'GOLD_' ~ team_name] %}

    {% for sch in team_schemas %}
        grant usage on schema BIKESHARE{{env_suffix}}.{{sch}} to role BIKESHARE_{{team_name}}_READER{{env_suffix}};
        grant select on all tables in schema BIKESHARE{{env_suffix}}.{{sch}} to role BIKESHARE_{{team_name}}_READER{{env_suffix}};
    {% endfor %}

{% endmacro %}