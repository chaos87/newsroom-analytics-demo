{{
    config(
        enabled= var('conversion_events', false) != false,
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = 'session_partition_key',
        tags = ["incremental"]
    )
}}

with event_counts as (
    select
        session_key,
        session_partition_key,
        min(event_date_dt) as session_partition_date -- The date of this session partition
        {% for ce in var('conversion_events',[]) %}
        , count(*) filter (where event_name = '{{ce}}') as {{ga4.valid_column_name(ce)}}_count
        {% endfor %}
    from {{ref('stg_ga4__events')}}
    where 1=1
    {% if is_incremental() %}
            and event_date_dt in (
            {%- for i in range(var('static_incremental_days', 3) + 1) %}
                current_date - {{ i }}{{ "," if not loop.last }}
            {%- endfor %}
            )
    {% endif %}
    group by 1,2
)

select * from event_counts