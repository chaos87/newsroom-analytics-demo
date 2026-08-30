{#-
    fct_ga4__sessions_daily — Postgres port.
    Incremental delete+insert keyed on session_partition_key; the incremental
    window mirrors upstream's insert_overwrite partitions (current_date and the
    previous static_incremental_days days).
    Port substitutions: countif → count(*) filter, ifnull → coalesce.
-#}
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = 'session_partition_key',
        tags = ["incremental"]
    )
}}

with session_metrics as (
    select
        session_key,
        session_partition_key,
        client_key,
        stream_id,
        max(user_id) as user_id, -- user_id can be null at the start and end of a session and still be set in the middle
        min(event_date_dt) as session_partition_date, -- Date of the session partition, does not represent the true session start date which, in GA4, can span multiple days
        min(event_timestamp) as session_partition_min_timestamp,
        count(*) filter (where event_name = 'page_view') as session_partition_count_page_views,
        sum(event_value_in_usd) as session_partition_sum_event_value_in_usd,
        coalesce(max(session_engaged), 0) as session_partition_max_session_engaged,
        sum(engagement_time_msec) as session_partition_sum_engagement_time_msec,
        min(session_number) as session_number
    from {{ref('stg_ga4__events')}}
    where session_key is not null
    {% if is_incremental() %}
            and event_date_dt in (
            {%- for i in range(var('static_incremental_days', 3) + 1) %}
                current_date - {{ i }}{{ "," if not loop.last }}
            {%- endfor %}
            )
    {% endif %}
    group by 1,2,3,4
)
{% if var('conversion_events', false) == false %}
    select * from session_metrics
{% else %}
    ,
    session_conversions as (
    select * from {{ref('stg_ga4__session_conversions_daily')}}
    where 1=1
    {% if is_incremental() %}
            and session_partition_date in (
            {%- for i in range(var('static_incremental_days', 3) + 1) %}
                current_date - {{ i }}{{ "," if not loop.last }}
            {%- endfor %}
            )
    {% endif %}
    ),
    join_metrics_and_conversions as (
        select
            session_metrics.session_key,
            session_metrics.client_key,
            session_metrics.stream_id,
            session_metrics.user_id,
            session_metrics.session_partition_key,
            session_metrics.session_partition_date,
            session_metrics.session_partition_min_timestamp,
            session_metrics.session_partition_count_page_views,
            session_metrics.session_partition_sum_event_value_in_usd,
            session_metrics.session_partition_max_session_engaged,
            session_metrics.session_partition_sum_engagement_time_msec,
            session_metrics.session_number
            {% for ce in var('conversion_events', []) %}
            , session_conversions.{{ ga4.valid_column_name(ce) }}_count
            {% endfor %}
        from session_metrics
        left join session_conversions using (session_partition_key)
    )

    select * from join_metrics_and_conversions
{% endif %}