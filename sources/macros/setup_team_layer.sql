-- ==========================================
-- MACRO 2 : Pour les équipes métier (et leurs inputs manuels)
-- ==========================================
{% macro setup_team_layer(team_name) %}

    -- 1. Création du rôle reader de l'équipe
    define role {{compagny}}_{{team_name}}_READER{{env_suffix}} comment = '🚲 Reads {{team_name}} specific data';
    grant role {{compagny}}_{{team_name}}_READER{{env_suffix}} to role {{compagny}}_READER{{env_suffix}};

    -- 2. Propriété : Manual Inputs et Couches Métier
    grant ownership on schema {{compagny}}{{env_suffix}}.BRONZE_MI_{{team_name}} to role {{compagny}}_LOADER{{env_suffix}} revoke current grants;
    grant ownership on schema {{compagny}}{{env_suffix}}.SILVER_MI_{{team_name}} to role {{compagny}}_TRANSFORMER{{env_suffix}} revoke current grants;
    grant ownership on schema {{compagny}}{{env_suffix}}.SILVER_{{team_name}} to role {{compagny}}_TRANSFORMER{{env_suffix}} revoke current grants;
    grant ownership on schema {{compagny}}{{env_suffix}}.GOLD_{{team_name}} to role {{compagny}}_TRANSFORMER{{env_suffix}} revoke current grants;

    -- 3. Accès de base pour le rôle de l'équipe
    grant usage on database {{compagny}}{{env_suffix}} to role {{compagny}}_{{team_name}}_READER{{env_suffix}};
    grant usage on warehouse {{compagny}}_READING_WH{{env_suffix}} to role {{compagny}}_{{team_name}}_READER{{env_suffix}};

    -- 4. Droits de lecture sur les schémas de l'équipe
    {% set team_schemas = ['BRONZE_MI_' ~ team_name, 'SILVER_MI_' ~ team_name, 'SILVER_' ~ team_name, 'GOLD_' ~ team_name] %}
    {% set object_types = ['TABLES', 'VIEWS', 'MATERIALIZED VIEWS', 'DYNAMIC TABLES', 'EXTERNAL TABLES'] %}

    {% for sch in team_schemas %}
        -- Accès au conteneur (schéma)
        grant usage on schema {{compagny}}{{env_suffix}}.{{sch}} to role {{compagny}}_{{team_name}}_READER{{env_suffix}};

        -- Accès aux objets (Existants et Futurs)
        {% for obj in object_types %}
            grant select on all {{obj}} in schema {{compagny}}{{env_suffix}}.{{sch}} to role {{compagny}}_{{team_name}}_READER{{env_suffix}};
            grant select on future {{obj}} in schema {{compagny}}{{env_suffix}}.{{sch}} to role {{compagny}}_{{team_name}}_READER{{env_suffix}};
        {% endfor %}
    {% endfor %}

{% endmacro %}