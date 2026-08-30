{#-
    Daily article performance: GA4 analytics joined against the CMS export.

    Single-pass design: one scan of stg_ga4__events with per-event param
    extraction (article_id / item_id from event_params, video & engagement via
    page_location), then conditional aggregation per (event_date, article).
    This keeps the model within Neon's smallest compute (0.25 CU) — the
    original draft scanned the staging view once per event type.
-#}
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = ['event_date_dt', 'article_id'],
        tags = ["incremental"]
    )
}}

with article_events as (
    select
        event_date_dt
        , event_name
        , client_key
        , session_number
        , {{ ga4.unnest_key('event_params', 'entrances', 'int_value') }}
        , engagement_time_msec
        , page_location
        , {{ ga4.unnest_key('event_params', 'article_id') }}
        , {{ ga4.unnest_key('event_params', 'item_id') }}
        , {{ ga4.unnest_key('event_params', 'percent_scrolled', 'int_value') }}
    from {{ ref('stg_ga4__events') }}
    where event_name in (
        'page_view', 'scroll', 'share', 'bookmark', 'comment',
        'newsletter_signup', 'user_engagement', 'video_start', 'video_complete'
    )
    {% if is_incremental() %}
        and event_date_dt in (
        {%- for i in range(var('static_incremental_days', 3) + 1) %}
            current_date - {{ i }}{{ "," if not loop.last }}
        {%- endfor %}
        )
    {% endif %}
),
enriched as (
    select
        event_date_dt
        , event_name
        , client_key
        , session_number
        , coalesce(entrances, 0) as entrances
        , engagement_time_msec
        , percent_scrolled
        , cast(
            case
                when event_name = 'share' then item_id
                when event_name in ('page_view', 'scroll', 'bookmark', 'comment') then article_id
                else substring(page_location from 'article-([0-9]+)')
            end
          as integer) as article_id
    from article_events
    where coalesce(article_id, item_id) is not null
       or page_location like '%article-%'
),
article_daily as (
    select
        event_date_dt
        , article_id
        , count(*) filter (where event_name = 'page_view') as page_views
        , count(distinct client_key) filter (where event_name = 'page_view') as distinct_client_keys
        , sum(case when event_name = 'page_view' and session_number = 1 then 1 else 0 end) as new_client_keys
        , sum(case when event_name = 'page_view' then entrances else 0 end) as entrances
        , count(*) filter (where event_name = 'scroll') as scroll_events
        , avg(percent_scrolled) filter (where event_name = 'scroll') as avg_scroll_percent
        , count(*) filter (where event_name = 'share') as share_events
        , count(*) filter (where event_name = 'bookmark') as bookmark_events
        , count(*) filter (where event_name = 'comment') as comment_events
        , count(*) filter (where event_name = 'video_start') as video_starts
        , count(*) filter (where event_name = 'video_complete') as video_completes
        , coalesce(sum(engagement_time_msec) filter (where event_name = 'user_engagement'), 0) as engagement_time_msec
        , count(*) filter (where event_name = 'newsletter_signup') as newsletter_signups
    from enriched
    where article_id is not null
    group by 1, 2
)

select
    ad.event_date_dt
    , ad.article_id
    , a.title
    , a.section
    , a.author
    , a.published_at
    , a.word_count
    , a.is_breaking
    , a.has_video
    , ad.page_views
    , ad.distinct_client_keys
    , ad.new_client_keys
    , ad.entrances
    , ad.scroll_events
    , ad.avg_scroll_percent
    , ad.share_events
    , ad.bookmark_events
    , ad.comment_events
    , ad.video_starts
    , ad.video_completes
    , ad.engagement_time_msec
    , ad.newsletter_signups
from article_daily ad
join {{ source('cms', 'articles') }} a on ad.article_id = a.article_id