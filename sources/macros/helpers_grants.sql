-- ==========================================
-- HELPER : Droits de LECTURE sur un schéma
-- ==========================================
{% macro grant_read_on_schema(schema_name, reader_role) %}

    grant usage on schema {{ schema_name }} to role {{ reader_role }};

    {% set object_types = ['TABLES', 'VIEWS', 'MATERIALIZED VIEWS', 'DYNAMIC TABLES', 'EXTERNAL TABLES'] %}
    {% for obj in object_types %}
        grant select on all {{obj}} in schema {{ schema_name }} to role {{ reader_role }};
        grant select on future {{obj}} in schema {{ schema_name }} to role {{ reader_role }};
    {% endfor %}

{% endmacro %}


-- ==========================================
-- HELPER : Droits d'ÉCRITURE/CRÉATION sur un schéma
-- ==========================================
{% macro grant_write_on_schema(schema_name, writer_role, role_type) %}

    grant usage on schema {{ schema_name }} to role {{ writer_role }};

    -- Objets de modélisation standards (Loader & Transformer)
    grant create table on schema {{ schema_name }} to role {{ writer_role }};
    grant create view on schema {{ schema_name }} to role {{ writer_role }};
    grant create dynamic table on schema {{ schema_name }} to role {{ writer_role }};

    -- Objets spécifiques à l'ingestion (Loader uniquement)
    {% if role_type == 'LOADER' %}
        grant create stage on schema {{ schema_name }} to role {{ writer_role }};
        grant create file format on schema {{ schema_name }} to role {{ writer_role }};
        grant create pipe on schema {{ schema_name }} to role {{ writer_role }}; -- Utile pour Snowpipe
    {% endif %}

{% endmacro %}