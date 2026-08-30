-- Port addition: video_progress fires at the 25%, 50% and 75% playback
-- thresholds (GA4 enhanced measurement). Upstream only ships
-- video_start / video_complete.
 with video_progress_with_params as (
   select *,
      {{ ga4.unnest_key('event_params', 'video_current_time', 'int_value') }},
      {{ ga4.unnest_key('event_params', 'video_duration', 'int_value') }},
      {{ ga4.unnest_key('event_params', 'video_percent', 'int_value') }},
      {{ ga4.unnest_key('event_params', 'video_url') }},
      {{ ga4.unnest_key('event_params', 'video_provider') }},
      {{ ga4.unnest_key('event_params', 'video_title') }},
      {{ ga4.unnest_key('event_params', 'visible') }}
 from {{ref('stg_ga4__events')}}
 where event_name = 'video_progress'
)

select * from video_progress_with_params