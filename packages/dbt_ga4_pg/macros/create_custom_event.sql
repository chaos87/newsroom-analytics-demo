{#- Creates a staging model for any custom event, flattening any custom
    parameters defined via [event name]_custom_parameters / default_custom_parameters.
    Identical SQL to upstream — works as-is on Postgres once unnest_key is ported.
-#}
{%- macro create_custom_event(event_name) -%}
    select *
        {% if var("default_custom_parameters", "none") != "none" %}
            {{ ga4.stage_custom_parameters( var("default_custom_parameters", "none") )}}
        {% endif %}
        {% if var(event_name+"_custom_parameters", "none") != "none" %}
            {{ ga4.stage_custom_parameters( var(event_name+"_custom_parameters") )}}
        {% endif %}
    from {{ref('stg_ga4__events')}}
    where event_name = '{{event_name}}'
{%- endmacro -%}