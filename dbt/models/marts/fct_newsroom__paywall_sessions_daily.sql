{#-
    One row per session-day that served at least one paywall impression —
    the exact denominator for Paywall Conversion Rate (New Subscribers ÷
    sessions exposed to the paywall, METRICS.md). Carries the session's
    wall impressions and CTA clicks.
-#}
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = ['event_date_dt', 'session_partition_key'],
        tags = ["incremental"]
    )
}}

with paywall_events as (
    select
        event_date_dt
        , event_name
        , session_partition_key
    from {{ ref('stg_ga4__events') }}
    where event_name in ('paywall_impression', 'paywall_click')
    {% if is_incremental() %}
        and event_date_dt in (
        {%- for i in range(var('static_incremental_days', 3) + 1) %}
            current_date - {{ i }}{{ "," if not loop.last }}
        {%- endfor %}
        )
    {% endif %}
)

select
    event_date_dt
    , session_partition_key
    , count(*) filter (where event_name = 'paywall_impression') as paywall_impressions
    , count(*) filter (where event_name = 'paywall_click') as paywall_clicks
from paywall_events
group by 1, 2
having count(*) filter (where event_name = 'paywall_impression') > 0