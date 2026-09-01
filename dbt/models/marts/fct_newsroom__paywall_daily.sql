{#-
    Daily paywall funnel by article, wall variant and bundle offer: paywall
    impressions and subscribe-CTA clicks served to non-subscribers. One row
    per (event_date_dt, article_id, paywall_type, bundle_offer).

    Wall variants (generator policy, METRICS.md):
      hard    — premium sections, walled on every non-subscriber hit
      metered — other paywalled sections, walled after 3 free article
                reads per calendar month
-#}
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = ['event_date_dt', 'article_id', 'paywall_type', 'bundle_offer'],
        tags = ["incremental"]
    )
}}

with paywall_events as (
    select
        event_date_dt
        , event_name
        , {{ ga4.unnest_key('event_params', 'article_id') }}
        , {{ ga4.unnest_key('event_params', 'paywall_type') }}
        , {{ ga4.unnest_key('event_params', 'bundle_offer') }}
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
    , cast(article_id as integer) as article_id
    , paywall_type
    , bundle_offer
    , count(*) filter (where event_name = 'paywall_impression') as paywall_impressions
    , count(*) filter (where event_name = 'paywall_click') as paywall_clicks
from paywall_events
where article_id is not null
group by 1, 2, 3, 4