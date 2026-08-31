{#-
    Last-touch attribution for subscriptions.

    One row per subscriber, driven by the GA4 `subscribe` event when present
    (path A), falling back to CRM-only semantics otherwise (path B):

    Path A — subscribe event exists (generator ≥ conversion sessions):
      - subscription_timestamp = the subscribe event's exact timestamp
      - purchase session = the session containing the subscribe event
      - last article read = latest article page_view strictly before the
        subscribe moment, within 7 days (typically the paywall article the
        reader was on when converting)
      - paywall_article_id = the article the subscribe event fired on

    Path B — fallback (no subscribe event in the export yet):
      - subscription moment = CRM registration_date (day granularity)
      - purchase session = last session on/before the subscription date
      - last article read = latest article page_view in the 7 days before
        the subscription date

    Both paths carry: reader state at the last read ('registered' if the
    event carried a GA4 user_id, 'anonymous' otherwise), purchase-session
    platform / device / geo, and the session's first-click traffic source /
    channel grouping (30-day last-non-direct lives upstream in the package).

    Identity: registered readers keep one stable user_pseudo_id across
    their anonymous → subscribed lifetime, so device-level linkage stitches
    pre-registration anonymous reads to the conversion.

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

subscribe_events as (
    select
        e.user_id
        , e.session_partition_key
        , e.event_date_dt
        , e.event_timestamp as subscription_ts
        , {{ ga4.unnest_key('event_params', 'article_id', 'string_value', 'paywall_article_id') }}
    from {{ ref('stg_ga4__events') }} e
    where e.event_name = 'subscribe'
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

session_starts as (
    select
        subscriber_user_id
        , session_partition_key
        , event_date_dt
        , event_timestamp
        , platform
        , device_category
        , device_operating_system
        , device_browser
        , geo_country
        , geo_region
        , geo_city
    from subscriber_events
    where event_name = 'session_start'
),

purchase_sessions as (
    -- path A: the session containing the subscribe event
    select
        s.user_id as subscriber_user_id
        , ss.session_partition_key
        , ss.event_date_dt as purchase_session_date
        , ss.event_timestamp as purchase_session_ts
        , ss.platform
        , ss.device_category
        , ss.device_operating_system
        , ss.device_browser
        , ss.geo_country
        , ss.geo_region
        , ss.geo_city
        , 1 as path_priority
    from subscribers s
    join subscribe_events ev on ev.user_id = s.user_id
    join session_starts ss
        on ss.subscriber_user_id = s.user_id
       and ss.session_partition_key = ev.session_partition_key

    union all

    -- path B (fallback): last session on/before the CRM subscription date
    select
        ss.subscriber_user_id
        , ss.session_partition_key
        , ss.event_date_dt
        , ss.event_timestamp
        , ss.platform
        , ss.device_category
        , ss.device_operating_system
        , ss.device_browser
        , ss.geo_country
        , ss.geo_region
        , ss.geo_city
        , 2 as path_priority
    from session_starts ss
    join subscribers s2 on s2.user_id = ss.subscriber_user_id
    where ss.event_date_dt <= s2.subscription_date
      and not exists (
            select 1 from subscribe_events ev2
            where ev2.user_id = s2.user_id
          )
),

purchase_session_ranked as (
    select
        *
        , row_number() over (
            partition by subscriber_user_id
            order by path_priority, purchase_session_ts desc
          ) as rn
    from purchase_sessions
),

last_reads as (
    -- path A: last article read strictly before the subscribe moment,
    -- within 7 days
    select
        se.subscriber_user_id
        , cast(
            coalesce(se.article_id, substring(se.page_location from 'article-([0-9]+)'))
          as integer) as article_id
        , se.event_timestamp
        , case when se.event_user_id is not null then 'registered' else 'anonymous' end
            as reader_state
        , 1 as path_priority
    from subscriber_events se
    join subscribe_events ev on ev.user_id = se.subscriber_user_id
    where se.event_name = 'page_view'
      and se.event_timestamp < ev.subscription_ts
      and se.event_timestamp >= ev.subscription_ts - 604800000000  -- 7 days in micros
      and coalesce(se.article_id, substring(se.page_location from 'article-([0-9]+)')) is not null

    union all

    -- path B (fallback): last article read in the 7 days before the
    -- CRM subscription date
    select
        se.subscriber_user_id
        , cast(
            coalesce(se.article_id, substring(se.page_location from 'article-([0-9]+)'))
          as integer)
        , se.event_timestamp
        , case when se.event_user_id is not null then 'registered' else 'anonymous' end
        , 2 as path_priority
    from subscriber_events se
    join subscribers s2 on s2.user_id = se.subscriber_user_id
    where se.event_name = 'page_view'
      and se.event_date_dt between s2.subscription_date - 7 and s2.subscription_date
      and coalesce(se.article_id, substring(se.page_location from 'article-([0-9]+)')) is not null
      and not exists (
            select 1 from subscribe_events ev2
            where ev2.user_id = s2.user_id
          )
),

last_read_ranked as (
    select
        *
        , row_number() over (
            partition by subscriber_user_id
            order by path_priority, event_timestamp desc
          ) as rn
    from last_reads
)

select
    s.user_id
    , s.subscription_tier
    , s.subscription_date
    , case when ev.user_id is not null then 'subscribe_event' else 'crm_only' end
        as subscription_source
    , to_timestamp(ev.subscription_ts / 1000000.0) as subscription_timestamp
    , cast(ev.paywall_article_id as integer) as paywall_article_id
    , pw.title as paywall_article_title
    , ps.session_partition_key as purchase_session_key
    , ps.purchase_session_date
    , to_timestamp(ps.purchase_session_ts / 1000000.0) as purchase_session_start
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
    , to_timestamp(la.event_timestamp / 1000000.0) as last_article_read_at
    , la.reader_state as last_article_reader_state
    , case
        when la.event_timestamp is not null
            then s.subscription_date - to_timestamp(la.event_timestamp / 1000000.0)::date
      end as days_last_read_before_subscription
from subscribers s
left join subscribe_events ev
    on ev.user_id = s.user_id
left join purchase_session_ranked ps
    on ps.subscriber_user_id = s.user_id
   and ps.rn = 1
left join {{ ref('stg_ga4__sessions_traffic_sources_daily') }} ts
    on ts.session_partition_key = ps.session_partition_key
left join last_read_ranked la
    on la.subscriber_user_id = s.user_id
   and la.rn = 1
left join {{ source('cms', 'articles') }} a
    on a.article_id = la.article_id
left join {{ source('cms', 'articles') }} pw
    on pw.article_id = cast(ev.paywall_article_id as integer)