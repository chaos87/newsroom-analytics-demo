{#- URL parsing helpers — Postgres port.
    BigQuery REGEXP_EXTRACT → substring(... from 'regex')
    BigQuery REGEXP_CONTAINS → ~ operator (see default_channel_grouping)
-#}

{% macro extract_hostname_from_url(url) %}
    nullif(substring({{ url }} from '(?:https?://)?(?:www\.)?([^/:?#]+)'), '')
{% endmacro %}

{% macro extract_query_string_from_url(url) %}
    nullif(substring({{ url }} from '\?(.+)'), '')
{% endmacro %}

{% macro remove_query_parameters(url, parameters) %}
  {% if "*all*" in parameters %}
    regexp_replace({{ url }}, '(\?|&|#).*', '')
  {% else %}
    regexp_replace({{ url }}, '([?&#]({{ parameters|join("|") }})=[^?&#]*)', '', 'g')
  {% endif %}
{% endmacro %}

{% macro extract_page_path(url) %}
    substring({{ url }} from '(?:\w+://)?//[^/]+([^?#]+)')
{% endmacro %}

{% macro extract_query_parameter_value(url, param) %}
    substring({{ url }} from '{{ param }}=([^&?&#]*)')
{% endmacro %}