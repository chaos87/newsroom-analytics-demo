{#-
    Daily article performance by reader type: subscribers vs registered
    non-subscribers vs anonymous readers, with the subscription tier for
    subscriber rows ('n/a' for registered / anonymous).

    reader_type is classified from the GA4 user_id carried on the event,
    joined to the CRM export (cms.users):
      - 'subscriber' : event user_id matches a CRM account with is_subscriber = true
      - 'registered' : event user_id matches a CRM account without a subscription
      - 'anonymous'  : no user_id on the event (logged-out / consent-denied /
                       unknown readers) — including unmatched user_ids

    Same single-pass design as fct_newsroom__articles_daily: one scan of
    stg_ga4__events with per-event param extraction, then conditional
    aggregation per (event_date, article, reader_type) — plus one cheap left
    join to cms.users (small CRM table) for the classification.
-#}
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = ['event_date_dt', 'article_id', 'reader_type', 'subscription_tier'],
        tags = ["incremental"]
    )
}}

with article_events as (
    select
        event_date_dt
        , event_name
        , client_key
        , session_number
        , user_id
        , engagement_time_msec
        , page_location
        , {{ ga4.unnest_key('event_params', 'entrances', 'int_value') }}
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
        , user_id
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
classified as (
    select
        e.event_date_dt
        , e.event_name
        , e.client_key
        , e.session_number
        , e.entrances
        , e.engagement_time_msec
        , e.percent_scrolled
        , e.article_id
        , case
            when u.user_id is not null and u.is_subscriber then 'subscriber'
            when u.user_id is not null then 'registered'
            else 'anonymous'
        end as reader_type
        , case
            when u.user_id is not null and u.is_subscriber
                then coalesce(u.subscription_tier, 'unknown')
            else 'n/a'
        end as subscription_tier
    from enriched e
    left join {{ source('cms', 'users') }} u on u.user_id = e.user_id
),
article_daily as (
    select
        event_date_dt
        , article_id
        , reader_type
        , subscription_tier
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
    from classified
    where article_id is not null
    group by 1, 2, 3, 4
)

select
    ad.event_date_dt
    , ad.article_id
    , ad.reader_type
    , ad.subscription_tier
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