{#-
    fct_ga4__pages — Postgres port.
    Incremental delete+insert keyed on page_key (upstream drops page_key from the
    output via `select * except(page_key)`; the port keeps it because the Postgres
    incremental strategy needs the key in the output).
    Port substitutions: countif → count(*) filter, if() → case when,
    ifnull → coalesce, * except → explicit column list.
-#}
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = 'page_key',
        tags = ["incremental"]
    )
}}

with page_view as (
    select
        event_date_dt,
        stream_id,
        page_location,  -- includes query string parameters not listed in query_parameter_exclusions variable
        page_key,
        page_engagement_key,
        count(event_name) as page_views,
        count(distinct client_key) as distinct_client_keys,
        sum(case when session_number = 1 then 1 else 0 end) as new_client_keys,
        sum(coalesce(entrances, 0)) as entrances
from {{ref('stg_ga4__event_page_view')}}
{% if is_incremental() %}
        where event_date_dt in (
        {%- for i in range(var('static_incremental_days', 3) + 1) %}
            current_date - {{ i }}{{ "," if not loop.last }}
        {%- endfor %}
        )
{% endif %}
    group by 1,2,3,4,5
), page_engagement as (
    select
        page_view.event_date_dt,
        page_view.stream_id,
        page_view.page_location,
        page_view.page_key,
        sum(page_view.page_views) as page_views,  -- page_engagement_key references the page_referrer; need to re-aggregate metrics
        sum(page_view.distinct_client_keys) as distinct_client_keys,
        sum(page_view.new_client_keys) as new_client_keys,
        sum(page_view.entrances) as entrances,
        sum(page_engagement_time_msec) as total_engagement_time_msec,
        sum(page_engagement_denominator) as avg_engagement_time_denominator
    from {{ ref('stg_ga4__page_engaged_time') }}
    right join page_view using (page_engagement_key)
    group by 1,2,3,4
), scroll as (
    select
        event_date_dt,
        page_location,
        count(event_name) as scroll_events
    from {{ref('stg_ga4__event_scroll')}}
    {% if is_incremental() %}
            where event_date_dt in (
            {%- for i in range(var('static_incremental_days', 3) + 1) %}
                current_date - {{ i }}{{ "," if not loop.last }}
            {%- endfor %}
            )
    {% endif %}
    group by 1,2
)
{% if var('conversion_events',false) %}
,
join_conversions as (
    select
        page_engagement.*
        {% for ce in var('conversion_events',[]) %}
        , coalesce(page_conversions.{{ ga4.valid_column_name(ce) }}_count, 0) as {{ ga4.valid_column_name(ce) }}_count
        {% endfor %}
    from page_engagement
    left join {{ ref('stg_ga4__page_conversions') }} page_conversions using (page_key)
)
select
    event_date_dt,
    stream_id,
    page_location,
    page_key,
    page_views,
    distinct_client_keys,
    new_client_keys,
    entrances,
    total_engagement_time_msec,
    avg_engagement_time_denominator
    {% for ce in var('conversion_events',[]) %}
    , {{ ga4.valid_column_name(ce) }}_count
    {% endfor %}
    , coalesce(scroll.scroll_events, 0) as scroll_events
from join_conversions
left join scroll using (event_date_dt, page_location)
{% else %}
select
    event_date_dt,
    stream_id,
    page_location,
    page_key,
    page_views,
    distinct_client_keys,
    new_client_keys,
    entrances,
    total_engagement_time_msec,
    avg_engagement_time_denominator,
    coalesce(scroll.scroll_events, 0) as scroll_events
from page_engagement
left join scroll using (event_date_dt, page_location)
{% endif %}