{#-
    Last non-direct session attribution within the lookback window
    (session_attribution_lookback_window_days, default 30 days).

    Postgres port notes:
      * Upstream: last_value(non_direct_session_partition_key IGNORE NULLS)
        OVER (PARTITION BY client_key ORDER BY session_partition_timestamp
        RANGE BETWEEN <lookback micros> PRECEDING AND CURRENT ROW).
      * Postgres has no IGNORE NULLS, so the port finds the most recent
        non-direct session timestamp inside the same RANGE frame with
        max(...) FILTER (...), then joins back to fetch that session's
        partition key and source.
-#}
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = 'session_partition_key',
        tags = ["incremental"]
    )
}}

with traffic_sources as (
    select
        client_key
        ,session_partition_key
        ,session_partition_date
        ,session_partition_timestamp
        ,session_source
        ,session_medium
        ,session_source_category
        ,session_campaign
        ,session_content
        ,session_term
        ,session_default_channel_grouping
        ,non_direct_session_partition_key
    from {{ref('stg_ga4__sessions_traffic_sources_daily')}}
    {% if is_incremental() %}
        -- widen the window by the attribution lookback so prior non-direct sessions are visible
        where session_partition_date >= current_date - ({{var('static_incremental_days', 3) + var('session_attribution_lookback_window_days', 30)}})
    {% endif %}
),
last_non_direct_timestamp as (
    select
        *
        ,max(session_partition_timestamp) filter (where non_direct_session_partition_key is not null)
            over (
                partition by client_key
                order by session_partition_timestamp
                range between {{ var('session_attribution_lookback_window_days', 30) * 24 * 60 * 60 * 1000000 }} preceding
                and current row
            ) as last_non_direct_timestamp
    from traffic_sources
),
session_partition_keys as (
    select
        t.client_key
        ,t.session_partition_key
        ,t.session_partition_date
        ,t.session_partition_timestamp
        ,t.session_source
        ,t.session_medium
        ,t.session_source_category
        ,t.session_campaign
        ,t.session_content
        ,t.session_term
        ,t.session_default_channel_grouping
        ,t.non_direct_session_partition_key
        ,t.last_non_direct_timestamp
        ,case
            when t.non_direct_session_partition_key is not null then t.non_direct_session_partition_key
            else nd_key_at_ts.session_partition_key
        end as session_partition_key_last_non_direct
    from last_non_direct_timestamp t
    left join traffic_sources nd_key_at_ts
        on t.client_key = nd_key_at_ts.client_key
        and t.last_non_direct_timestamp = nd_key_at_ts.session_partition_timestamp
        and nd_key_at_ts.non_direct_session_partition_key is not null
    {% if is_incremental() %}
        -- only rebuild the current incremental window
        where t.session_partition_date in (
        {%- for i in range(var('static_incremental_days', 3) + 1) %}
            current_date - {{ i }}{{ "," if not loop.last }}
        {%- endfor %}
        )
    {% endif %}
)

select
    t.client_key
    ,t.session_partition_key
    ,t.session_partition_date
    ,t.session_partition_timestamp
    ,t.session_source
    ,t.session_medium
    ,t.session_source_category
    ,t.session_campaign
    ,t.session_content
    ,t.session_term
    ,t.session_default_channel_grouping
    ,t.non_direct_session_partition_key
    ,t.session_partition_key_last_non_direct
    ,coalesce(nd.session_source, '(direct)') as last_non_direct_source
    ,coalesce(nd.session_medium, '(none)') as last_non_direct_medium
    ,coalesce(nd.session_source_category, '(none)') as last_non_direct_source_category
    ,coalesce(nd.session_campaign, '(none)') as last_non_direct_campaign
    ,coalesce(nd.session_content, '(none)') as last_non_direct_content
    ,coalesce(nd.session_term, '(none)') as last_non_direct_term
    ,coalesce(nd.session_default_channel_grouping, 'Direct') as last_non_direct_default_channel_grouping
from session_partition_keys t
left join traffic_sources nd
    on t.session_partition_key_last_non_direct = nd.session_partition_key