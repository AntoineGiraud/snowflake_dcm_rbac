-- ==========================================
-- MACRO 1 : Pour les systèmes sources (SAP, SF)
-- ==========================================
{% macro setup_source_layer(src_name) %}

    -- 1. Propriété : Loader charge le brut, Transformer gère le staging
    grant ownership on schema BIKESHARE{{env_suffix}}.BRONZE_{{src_name}} to role BIKESHARE_LOADER{{env_suffix}} revoke current grants;
    grant ownership on schema BIKESHARE{{env_suffix}}.SILVER_{{src_name}} to role BIKESHARE_TRANSFORMER{{env_suffix}} revoke current grants;

    -- 2. Variables Jinja pour boucler proprement
    {% set source_schemas = ['BRONZE_' ~ src_name, 'SILVER_' ~ src_name] %}
    {% set object_types = ['TABLES', 'VIEWS', 'MATERIALIZED VIEWS', 'DYNAMIC TABLES', 'EXTERNAL TABLES'] %}

    -- 3. Application des droits de lecture
    {% for sch in source_schemas %}
        -- Accès au conteneur (schéma)
        grant usage on schema BIKESHARE{{env_suffix}}.{{sch}} to role BIKESHARE_READER{{env_suffix}};
        -- Accès aux objets (Existants et Futurs)
        {% for obj in object_types %}
            grant select on all {{obj}} in schema BIKESHARE{{env_suffix}}.{{sch}} to role BIKESHARE_READER{{env_suffix}};
            grant select on future {{obj}} in schema BIKESHARE{{env_suffix}}.{{sch}} to role BIKESHARE_READER{{env_suffix}};
        {% endfor %}
    {% endfor %}

{% endmacro %}