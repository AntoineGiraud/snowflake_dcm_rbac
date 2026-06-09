-- ==========================================
-- MACRO 1 : Pour les systèmes sources (SAP, SF)
-- ==========================================
{% macro setup_source_layer(src_name) %}

    -- 1. Variables pour simplifier les appels
    {% set db_prefix = compagny ~ env_suffix ~ '.' %}
    {% set loader_role = compagny ~ '_LOADER' ~ env_suffix %}
    {% set transformer_role = compagny ~ '_TRANSFORMER' ~ env_suffix %}
    {% set global_reader_role = compagny ~ '_READER' ~ env_suffix %}

    -- 2. Attribution des droits d'ÉCRITURE via la macro Helper
    -- Le Loader ingère la donnée brute (avec droits potentiels sur les stages/pipes)
    {{ grant_write_on_schema(db_prefix ~ 'BRONZE_' ~ src_name, loader_role, 'LOADER') }}

    -- Le Transformer normalise la donnée
    {{ grant_write_on_schema(db_prefix ~ 'SILVER_' ~ src_name, transformer_role, 'TRANSFORMER') }}

    -- 3. Attribution des droits de LECTURE via la macro Helper
    -- Le Reader global a accès en lecture à toutes les sources
    {% set source_schemas = ['BRONZE_' ~ src_name, 'SILVER_' ~ src_name] %}

    {% for sch in source_schemas %}
        {{ grant_read_on_schema(db_prefix ~ sch, global_reader_role) }}
    {% endfor %}

{% endmacro %}