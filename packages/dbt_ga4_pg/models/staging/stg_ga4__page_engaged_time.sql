-- Postgres port: page_engagement_key is computed inline (upstream reads it from
-- stg_ga4__events, where page_views get a referrer-based key). Engagement events
-- (user_engagement, scroll, ...) carry page_location, which pairs with the
-- page_view rows' page_location-based key recomputed in stg_ga4__event_page_view.
with pek_time as (
select
    case
        when event_name = 'page_view' then md5(session_key || page_referrer)
        else md5(session_key || page_location)
    end as page_engagement_key,
    sum(engagement_time_msec) as page_engagement_time
from {{ ref('stg_ga4__events') }}
group by 1
),
matched_pv as ( -- need to replace the pek with one that uses page_location to match back to correct page_view
    select
        md5(session_key || page_location) as page_engagement_key
    from {{ ref('stg_ga4__events') }}
    where event_name = 'page_view'
),
denominator as (
    select
        page_engagement_key,
        count(page_engagement_key) as page_engagement_denominator --for sessions with multiple hits to the same page
    from matched_pv
    group by 1
)
select
    denominator.page_engagement_key,
    case
        when pek_time.page_engagement_time is null then null -- page views with no recorded engagement time must not factor in to later calculations
        else pek_time.page_engagement_time / nullif(denominator.page_engagement_denominator, 0)
    end as page_engagement_time_msec, --technically the average engagement time for that page in that session
    case
        when pek_time.page_engagement_time is null then null -- remove page_views with no engagement time from the denominator
        else denominator.page_engagement_denominator
    end as page_engagement_denominator
from denominator
left join pek_time using(page_engagement_key)