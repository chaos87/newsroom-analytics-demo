{#-
    Unnests a single key's value from a REPEATED RECORD array (JSONB on Postgres).
    BigQuery version: (select value.<type> from unnest(<col>) where key = '<key>')
    Postgres port:     (select (ep->'value'->>'<type>')::<type> from jsonb_array_elements(<col>) ep where ep->>'key' = '<key>')

    ga_session_id special case (kept from upstream): GA4 may send ga_session_id as
    an int_value, or as a string_value in the format 's1747075570$o5$g1$t...' where
    the leading 's<unix seconds>' segment holds the session id.
-#}
{%- macro unnest_key(column_to_unnest, key_to_extract, value_type = "string_value", rename_column = "default") -%}
    {%- set alias = key_to_extract if rename_column == "default" else rename_column -%}
    {%- if key_to_extract == "ga_session_id" and column_to_unnest == "event_params" -%}
    coalesce(
        (select (ep->'value'->>'int_value')::bigint
         from jsonb_array_elements(event_params) ep
         where ep->>'key' = 'ga_session_id')
        , nullif(split_part(split_part(
            (select ep->'value'->>'string_value'
             from jsonb_array_elements(event_params) ep
             where ep->>'key' = 'ga_session_id')
            , '$', 1), 's', 2), '')::bigint
        , 0
    ) as {{ alias }}
    {%- elif value_type == "lower_string_value" -%}
    (select lower(ep->'value'->>'string_value')
     from jsonb_array_elements({{ column_to_unnest }}) ep
     where ep->>'key' = '{{ key_to_extract }}') as {{ alias }}
    {%- elif value_type == "string_value" -%}
    (select ep->'value'->>'string_value'
     from jsonb_array_elements({{ column_to_unnest }}) ep
     where ep->>'key' = '{{ key_to_extract }}') as {{ alias }}
    {%- elif value_type == "int_value" -%}
    (select (ep->'value'->>'int_value')::bigint
     from jsonb_array_elements({{ column_to_unnest }}) ep
     where ep->>'key' = '{{ key_to_extract }}') as {{ alias }}
    {%- elif value_type in ("float_value", "double_value") -%}
    (select (ep->'value'->>'{{ value_type }}')::double precision
     from jsonb_array_elements({{ column_to_unnest }}) ep
     where ep->>'key' = '{{ key_to_extract }}') as {{ alias }}
    {%- else -%}
    (select ep->'value'->>'{{ value_type }}'
     from jsonb_array_elements({{ column_to_unnest }}) ep
     where ep->>'key' = '{{ key_to_extract }}') as {{ alias }}
    {%- endif -%}
{%- endmacro -%}