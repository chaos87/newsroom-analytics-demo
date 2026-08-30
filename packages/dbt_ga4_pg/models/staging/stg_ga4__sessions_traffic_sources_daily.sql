{#-
    Session traffic sources — daily variant. Postgres port.

    Upstream (BQ) uses FIRST_VALUE(...) IGNORE NULLS OVER (PARTITION BY session
    ORDER BY event_timestamp) to find the first non-direct source of each
    session partition. Postgres has no IGNORE NULLS, so the port expresses the
    same semantics with DISTINCT ON: the first row per session_partition_key
    ordered by event_timestamp among non-direct events, falling back to
    '(direct)' for sessions that never had a non-direct event.
-#}
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = 'session_partition_key',
        tags = ["incremental"]
    )
}}

with session_events as (
    select
        client_key
        ,session_partition_key
        ,event_date_dt as session_partition_date
        ,event_timestamp
        ,events.event_source
        ,event_medium
        ,event_campaign
        ,event_content
        ,event_term
        ,source_category
    from {{ref('stg_ga4__events')}} events
    left join {{ref('ga4_source_categories')}} source_categories on events.event_source = source_categories.source
    where session_partition_key is not null
    and event_name != 'session_start'
    and event_name != 'first_visit'
    {% if is_incremental() %}
            and event_date_dt in (
            {%- for i in range(var('static_incremental_days', 3) + 1) %}
                current_date - {{ i }}{{ "," if not loop.last }}
            {%- endfor %}
            )
    {% endif %}
),
set_default_channel_grouping as (
    select
        *
        ,{{ga4.default_channel_grouping('event_source','event_medium','source_category', 'event_campaign')}} as default_channel_grouping
    from session_events
),
all_sessions as (
    select distinct
        client_key
        ,session_partition_key
        ,session_partition_date
    from set_default_channel_grouping
),
min_ts as (
    select
        session_partition_key
        ,min(event_timestamp) as session_partition_timestamp
    from set_default_channel_grouping
    group by 1
),
first_non_direct as (
    select distinct on (session_partition_key)
        session_partition_key
        ,event_source as session_source
        ,coalesce(event_medium, '(none)') as session_medium
        ,coalesce(source_category, '(none)') as session_source_category
        ,coalesce(event_campaign, '(none)') as session_campaign
        ,coalesce(event_content, '(none)') as session_content
        ,coalesce(event_term, '(none)') as session_term
        ,coalesce(default_channel_grouping, 'Direct') as session_default_channel_grouping
    from set_default_channel_grouping
    where event_source <> '(direct)'
    order by session_partition_key, event_timestamp asc
),
session_source as (
    select
        all_sessions.client_key
        ,all_sessions.session_partition_key
        ,all_sessions.session_partition_date
        ,coalesce(first_non_direct.session_source, '(direct)') as session_source
        ,coalesce(first_non_direct.session_medium, '(none)') as session_medium
        ,coalesce(first_non_direct.session_source_category, '(none)') as session_source_category
        ,coalesce(first_non_direct.session_campaign, '(none)') as session_campaign
        ,coalesce(first_non_direct.session_content, '(none)') as session_content
        ,coalesce(first_non_direct.session_term, '(none)') as session_term
        ,coalesce(first_non_direct.session_default_channel_grouping, 'Direct') as session_default_channel_grouping
        ,first_non_direct.session_partition_key as non_direct_session_partition_key
        ,min_ts.session_partition_timestamp
    from all_sessions
    left join first_non_direct using (session_partition_key)
    left join min_ts using (session_partition_key)
)

select * from session_source