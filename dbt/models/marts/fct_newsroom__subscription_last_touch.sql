{#-
    Last-touch attribution for subscriptions.

    For each subscriber (cms.users.is_subscriber = true):
      - last article read in the 7 days before their subscription date
        (reader state at that read: 'registered' if the event carried a GA4
        user_id, 'anonymous' otherwise — pre-registration reads are anonymous
        by definition in this dataset)
      - the purchase session: their last session on/before the subscription
        date (purchased_same_day flags whether that session happened on the
        subscription day itself), with platform, device, geo and the
        session's first-click traffic source / channel grouping.

    Semantics notes (this dataset):
      - The subscription moment is the CRM registration_date — subscribers
        register + subscribe the same day, and GA4 carries no explicit
        subscribe/purchase event. Day granularity, so the purchase session
        is the session context of the conversion day or, failing that, the
        most recent prior visit.
      - Identity: registered readers keep one stable user_pseudo_id across
        their anonymous → subscribed lifetime, so device-level linkage
        (user_pseudo_id) stitches pre-registration anonymous reads.

    Materialized as a table, not incremental: conversions are sparse and the
    lookback (7-day window + open-ended last session) exceeds the daily
    incremental window, while the model itself is tiny (one row per
    subscriber) and cheap to rebuild at demo scale.
-#}
{{
    config(
        materialized = 'table'
    )
}}

with subscribers as (
    select
        user_id
        , user_pseudo_id
        , registration_date as subscription_date
        , subscription_tier
    from {{ source('cms', 'users') }}
    where is_subscriber = true
),

subscriber_events as (
    select
        s.user_id as subscriber_user_id
        , s.subscription_date
        , e.event_name
        , e.event_date_dt
        , e.event_timestamp
        , e.user_id as event_user_id
        , e.session_partition_key
        , e.platform
        , e.device_category
        , e.device_operating_system
        , e.device_browser
        , e.geo_country
        , e.geo_region
        , e.geo_city
        , e.page_location
        , {{ ga4.unnest_key('event_params', 'article_id') }}
    from {{ ref('stg_ga4__events') }} e
    join subscribers s on e.user_pseudo_id = s.user_pseudo_id
    where e.event_date_dt <= s.subscription_date
),

purchase_sessions as (
    select
        subscriber_user_id
        , session_partition_key
        , event_date_dt as purchase_session_date
        , to_timestamp(event_timestamp / 1000000.0) as purchase_session_start
        , platform
        , device_category
        , device_operating_system
        , device_browser
        , geo_country
        , geo_region
        , geo_city
        , row_number() over (
            partition by subscriber_user_id
            order by event_timestamp desc
          ) as rn
    from subscriber_events
    where event_name = 'session_start'
),

last_article_reads as (
    select
        subscriber_user_id
        , cast(
            coalesce(article_id, substring(page_location from 'article-([0-9]+)'))
          as integer) as article_id
        , to_timestamp(event_timestamp / 1000000.0) as last_article_read_at
        , case when event_user_id is not null then 'registered' else 'anonymous' end
            as last_article_reader_state
        , row_number() over (
            partition by subscriber_user_id
            order by event_timestamp desc
          ) as rn
    from subscriber_events
    where event_name = 'page_view'
      and event_date_dt between subscription_date - 7 and subscription_date
      and coalesce(article_id, substring(page_location from 'article-([0-9]+)')) is not null
)

select
    s.user_id
    , s.subscription_tier
    , s.subscription_date
    , ps.session_partition_key as purchase_session_key
    , ps.purchase_session_date
    , ps.purchase_session_start
    , (ps.purchase_session_date = s.subscription_date) as purchased_same_day
    , ps.platform
    , ps.device_category
    , ps.device_operating_system
    , ps.device_browser
    , ps.geo_country
    , ps.geo_region
    , ps.geo_city
    , ts.session_source
    , ts.session_medium
    , ts.session_campaign
    , ts.session_default_channel_grouping
    , la.article_id as last_article_id
    , a.title as last_article_title
    , a.section as last_article_section
    , la.last_article_read_at
    , la.last_article_reader_state
    , case
        when la.last_article_read_at is not null
            then s.subscription_date - la.last_article_read_at::date
      end as days_last_read_before_subscription
from subscribers s
left join purchase_sessions ps
    on ps.subscriber_user_id = s.user_id
   and ps.rn = 1
left join {{ ref('stg_ga4__sessions_traffic_sources_daily') }} ts
    on ts.session_partition_key = ps.session_partition_key
left join last_article_reads la
    on la.subscriber_user_id = s.user_id
   and la.rn = 1
left join {{ source('cms', 'articles') }} a
    on a.article_id = la.article_id