-- ==========================================
-- MACRO 2 : Pour les équipes métier (et leurs inputs manuels)
-- ==========================================
{% macro setup_team_layer(team_name) %}

    -- 1. Variables pour simplifier les appels
    {% set db_prefix = compagny ~ env_suffix ~ '.' %}
    {% set loader_role = compagny ~ '_LOADER' ~ env_suffix %}
    {% set transformer_role = compagny ~ '_TRANSFORMER' ~ env_suffix %}
    {% set team_reader_role = compagny ~ '_' ~ team_name ~ '_READER' ~ env_suffix %}

    -- 2. Création du rôle reader de l'équipe
    define role {{ team_reader_role }} comment = '🚲 Reads {{team_name}} specific data';
    grant role {{ team_reader_role }} to role {{compagny}}_READER{{env_suffix}};

    -- 3. Accès de base à la DB et au WH
    grant usage on database {{compagny}}{{env_suffix}} to role {{ team_reader_role }};
    grant usage on warehouse {{compagny}}_READING_WH{{env_suffix}} to role {{ team_reader_role }};

    -- 4. Attribution des droits d'ÉCRITURE via la macro Helper (remplace les ownerships)
    {{ grant_write_on_schema(db_prefix ~ 'SILVER_' ~ team_name, transformer_role, 'TRANSFORMER') }}
    {{ grant_write_on_schema(db_prefix ~ 'GOLD_' ~ team_name, transformer_role, 'TRANSFORMER') }}

    -- 5. Attribution des droits de LECTURE via la macro Helper
    {% set team_schemas = ['SILVER_' ~ team_name, 'GOLD_' ~ team_name] %}

    {% for sch in team_schemas %}
        {{ grant_read_on_schema(db_prefix ~ sch, team_reader_role) }}
    {% endfor %}

{% endmacro %}