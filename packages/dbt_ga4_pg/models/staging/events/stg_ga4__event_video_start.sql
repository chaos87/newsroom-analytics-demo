-- GA4 enhanced-measurement video events (YouTube embeds with JS API enabled).
-- video_progress is a Postgres-port addition for the 25/50/75 thresholds
-- (upstream ships video_start / video_complete only).
 with video_start_with_params as (
   select *,
      {{ ga4.unnest_key('event_params', 'video_current_time', 'int_value') }},
      {{ ga4.unnest_key('event_params', 'video_duration', 'int_value') }},
      {{ ga4.unnest_key('event_params', 'video_percent', 'int_value') }},
      {{ ga4.unnest_key('event_params', 'video_url') }},
      {{ ga4.unnest_key('event_params', 'video_provider') }},
      {{ ga4.unnest_key('event_params', 'video_title') }},
      {{ ga4.unnest_key('event_params', 'visible') }}
      {% if var("default_custom_parameters", "none") != "none" %}
        {{ ga4.stage_custom_parameters( var("default_custom_parameters") )}}
      {% endif %}
      {% if var("video_start_custom_parameters", "none") != "none" %}
        {{ ga4.stage_custom_parameters( var("video_start_custom_parameters") )}}
      {% endif %}
 from {{ref('stg_ga4__events')}}
 where event_name = 'video_start'
)

select * from video_start_with_params