{#-
    Daily sessions by acquisition channel: GA4 default channel grouping with
    first-click (session) and last-non-direct attribution (30-day lookback).
-#}
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = ['session_partition_date', 'session_default_channel_grouping', 'session_source', 'session_medium'],
        tags = ["incremental"]
    )
}}

select
    d.session_partition_date
    , d.session_default_channel_grouping
    , d.session_source
    , d.session_medium
    , d.last_non_direct_source
    , d.last_non_direct_medium
    , d.last_non_direct_default_channel_grouping
    , count(distinct d.session_partition_key) as sessions
    , sum(f.session_partition_count_page_views) as page_views
    , sum(case when f.session_partition_max_session_engaged > 0 then 1 else 0 end) as engaged_sessions
    , sum(coalesce(f.newsletter_signup_count, 0)) as newsletter_signups
    , sum(f.session_partition_sum_engagement_time_msec) as engagement_time_msec
from {{ ref('dim_ga4__sessions_daily') }} d
join {{ ref('fct_ga4__sessions_daily') }} f using (session_partition_key)
{% if is_incremental() %}
where d.session_partition_date in (
    {%- for i in range(var('static_incremental_days', 3) + 1) %}
    current_date - {{ i }}{{ "," if not loop.last }}
    {%- endfor %}
)
{% endif %}
group by 1,2,3,4,5,6,7