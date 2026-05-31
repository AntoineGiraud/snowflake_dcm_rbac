-- ==========================================
-- MACRO 1 : Pour les systèmes sources (SAP, SF)
-- ==========================================
{% macro setup_source_layer(src_name) %}

    -- Propriété : Loader charge le brut, Transformer gère le staging
    grant ownership on schema BIKESHARE{{env_suffix}}.BRONZE_{{src_name}} to role BIKESHARE_LOADER{{env_suffix}} revoke current grants;
    grant ownership on schema BIKESHARE{{env_suffix}}.SILVER_{{src_name}} to role BIKESHARE_TRANSFORMER{{env_suffix}} revoke current grants;

    -- Le Reader global a accès en lecture aux sources
    grant usage on schema BIKESHARE{{env_suffix}}.BRONZE_{{src_name}} to role BIKESHARE_READER{{env_suffix}};
    grant usage on schema BIKESHARE{{env_suffix}}.SILVER_{{src_name}} to role BIKESHARE_READER{{env_suffix}};
    grant select on all tables in schema BIKESHARE{{env_suffix}}.BRONZE_{{src_name}} to role BIKESHARE_READER{{env_suffix}};
    grant select on all tables in schema BIKESHARE{{env_suffix}}.SILVER_{{src_name}} to role BIKESHARE_READER{{env_suffix}};

{% endmacro %}