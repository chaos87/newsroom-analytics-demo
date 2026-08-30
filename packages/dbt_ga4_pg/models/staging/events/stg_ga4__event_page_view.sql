-- GA4 page_view events with page-path levels and the page engagement key
-- recomputed on page_location (upstream recomputes page_engagement_key here
-- because stg_ga4__events assigns page_views a key based on page_referrer —
-- the engagement of a page is measured while the *next* page is in focus).
 with page_view_with_params as (
   select *,
      {{ ga4.unnest_key('event_params', 'entrances',  'int_value') }},
      {{ ga4.unnest_key('event_params', 'value', 'float_value') }},
      case when split_part(split_part(page_location, '/', 4), '?', 1) = '' then null else '/' || split_part(split_part(page_location, '/', 4), '?', 1) end as pagepath_level_1,
      case when split_part(split_part(page_location, '/', 5), '?', 1) = '' then null else '/' || split_part(split_part(page_location, '/', 5), '?', 1) end as pagepath_level_2,
      case when split_part(split_part(page_location, '/', 6), '?', 1) = '' then null else '/' || split_part(split_part(page_location, '/', 6), '?', 1) end as pagepath_level_3,
      case when split_part(split_part(page_location, '/', 7), '?', 1) = '' then null else '/' || split_part(split_part(page_location, '/', 7), '?', 1) end as pagepath_level_4,
      md5(session_key || page_location) as page_engagement_key
      {% if var("default_custom_parameters", "none") != "none" %}
        {{ ga4.stage_custom_parameters( var("default_custom_parameters") )}}
      {% endif %}
      {% if var("page_view_custom_parameters", "none") != "none" %}
        {{ ga4.stage_custom_parameters( var("page_view_custom_parameters") )}}
      {% endif %}
 from {{ref('stg_ga4__events')}}
 where event_name = 'page_view'
)
select *
from page_view_with_params