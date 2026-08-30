{{
    config(materialized = "table")
}}

-- Postgres port: upstream uses FIRST_VALUE/LAST_VALUE(event_key) over a client_key
-- window to get the first and last event of each client. The port uses
-- array_agg(...) with explicit ordering — identical semantics, no IGNORE NULLS
-- caveats since event_key is non-null whenever client_key is non-null.
with first_last_event as (
    select
        client_key,
        (array_agg(event_key order by event_timestamp asc))[1] as first_event,
        (array_agg(event_key order by event_timestamp desc))[1] as last_event,
        max(stream_id) as stream_id
    from {{ref('stg_ga4__events')}}
    where client_key is not null --remove users with privacy settings enabled
    group by client_key
),
events_joined as (
    select
        first_last_event.*,
        events_first.geo_continent as first_geo_continent,
        events_first.geo_country as first_geo_country,
        events_first.geo_region as first_geo_region,
        events_first.geo_city as first_geo_city,
        events_first.geo_sub_continent as first_geo_sub_continent,
        events_first.geo_metro as first_geo_metro,
        events_first.device_category as first_device_category,
        events_first.device_mobile_brand_name as first_device_mobile_brand_name,
        events_first.device_mobile_model_name as first_device_mobile_model_name,
        events_first.device_mobile_marketing_name as first_device_mobile_marketing_name,
        events_first.device_mobile_os_hardware_model as first_device_mobile_os_hardware_model,
        events_first.device_operating_system as first_device_operating_system,
        events_first.device_operating_system_version as first_device_operating_system_version,
        events_first.device_vendor_id as first_device_vendor_id,
        events_first.device_advertising_id as first_device_advertising_id,
        events_first.device_language as first_device_language,
        events_first.device_is_limited_ad_tracking as first_device_is_limited_ad_tracking,
        events_first.device_time_zone_offset_seconds as first_device_time_zone_offset_seconds,
        events_first.device_browser as first_device_browser,
        events_first.device_browser_version as first_device_browser_version,
        events_first.device_web_info_browser as first_device_web_info_browser,
        events_first.device_web_info_browser_version as first_device_web_info_browser_version,
        events_first.device_web_info_hostname as first_device_web_info_hostname,
        events_first.user_campaign as first_user_campaign,
        events_first.user_medium as first_user_medium,
        events_first.user_source as first_user_source,
        events_last.geo_continent as last_geo_continent,
        events_last.geo_country as last_geo_country,
        events_last.geo_region as last_geo_region,
        events_last.geo_city as last_geo_city,
        events_last.geo_sub_continent as last_geo_sub_continent,
        events_last.geo_metro as last_geo_metro,
        events_last.device_category as last_device_category,
        events_last.device_mobile_brand_name as last_device_mobile_brand_name,
        events_last.device_mobile_model_name as last_device_mobile_model_name,
        events_last.device_mobile_marketing_name as last_device_mobile_marketing_name,
        events_last.device_mobile_os_hardware_model as last_device_mobile_os_hardware_model,
        events_last.device_operating_system as last_device_operating_system,
        events_last.device_operating_system_version as last_device_operating_system_version,
        events_last.device_vendor_id as last_device_vendor_id,
        events_last.device_advertising_id as last_device_advertising_id,
        events_last.device_language as last_device_language,
        events_last.device_is_limited_ad_tracking as last_device_is_limited_ad_tracking,
        events_last.device_time_zone_offset_seconds as last_device_time_zone_offset_seconds,
        events_last.device_browser as last_device_browser,
        events_last.device_browser_version as last_device_browser_version,
        events_last.device_web_info_browser as last_device_web_info_browser,
        events_last.device_web_info_browser_version as last_device_web_info_browser_version,
        events_last.device_web_info_hostname as last_device_web_info_hostname,
        events_last.user_campaign as last_user_campaign,
        events_last.user_medium as last_user_medium,
        events_last.user_source as last_user_source
    from first_last_event
    left join {{ref('stg_ga4__events')}} events_first
        on first_last_event.first_event = events_first.event_key
    left join {{ref('stg_ga4__events')}} events_last
        on first_last_event.last_event = events_last.event_key
)

select * from events_joined