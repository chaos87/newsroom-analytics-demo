{#-
    dim_ga4__sessions_daily — Postgres port.
    Incremental (delete+insert on session_partition_key), reprocessing the same
    daily window as upstream's insert_overwrite partitions.

    Port note: upstream uses FIRST_VALUE(...) IGNORE NULLS over the session
    partition window. Postgres FIRST_VALUE picks the value from the first row of
    the frame; because GA4 carries geo/device/page fields on every event, the
    first event of a session partition holds non-null values for these, so the
    semantics match for this data.
-#}
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = 'session_partition_key',
        tags = ["incremental"]
    )
}}

with event_dimensions as
(
    select
        client_key,
        session_key,
        session_partition_key,
        event_date_dt as session_partition_date,
        event_timestamp,
        page_path,
        page_location,
        page_hostname,
        page_referrer,
        geo_continent,
        geo_country,
        geo_region,
        geo_city,
        geo_sub_continent,
        geo_metro,
        stream_id,
        platform,
        device_category,
        device_mobile_brand_name,
        device_mobile_model_name,
        device_mobile_marketing_name,
        device_mobile_os_hardware_model,
        device_operating_system,
        device_operating_system_version,
        device_vendor_id,
        device_advertising_id,
        device_language,
        device_is_limited_ad_tracking,
        device_time_zone_offset_seconds,
        device_browser,
        device_web_info_browser,
        device_web_info_browser_version,
        device_web_info_hostname,
        user_campaign,
        user_medium,
        user_source
    from {{ref('stg_ga4__events')}}
    where event_name != 'first_visit'
    and event_name != 'session_start'
    {% if is_incremental() %}
            and event_date_dt in (
            {%- for i in range(var('static_incremental_days', 3) + 1) %}
                current_date - {{ i }}{{ "," if not loop.last }}
            {%- endfor %}
            )
    {% endif %}
),
traffic_sources as (
    select
        session_partition_key,
        session_source,
        session_medium,
        session_campaign,
        session_content,
        session_term,
        session_default_channel_grouping,
        session_source_category,
        last_non_direct_source,
        last_non_direct_medium,
        last_non_direct_campaign,
        last_non_direct_content,
        last_non_direct_term,
        last_non_direct_default_channel_grouping,
        last_non_direct_source_category
    from {{ref('stg_ga4__sessions_traffic_sources_last_non_direct_daily')}}
    where 1=1
    {% if is_incremental() %}
            and session_partition_date in (
            {%- for i in range(var('static_incremental_days', 3) + 1) %}
                current_date - {{ i }}{{ "," if not loop.last }}
            {%- endfor %}
            )
    {% endif %}
),
session_dimensions as
(
    select
        distinct -- Distinct call will, in effect, group by session_partition_key
        stream_id
        ,session_key
        ,session_partition_key
        ,session_partition_date
        ,first_value(event_timestamp) over session_partition_window as session_partition_start_timestamp
        ,first_value(page_path) over session_partition_window as landing_page_path
        ,first_value(page_location) over session_partition_window as landing_page_location
        ,first_value(page_hostname) over session_partition_window as landing_page_hostname
        ,first_value(page_referrer) over session_partition_window as referrer
        ,first_value(geo_continent) over session_partition_window as geo_continent
        ,first_value(geo_country) over session_partition_window as geo_country
        ,first_value(geo_region) over session_partition_window as geo_region
        ,first_value(geo_city) over session_partition_window as geo_city
        ,first_value(geo_sub_continent) over session_partition_window as geo_sub_continent
        ,first_value(geo_metro) over session_partition_window as geo_metro
        ,first_value(platform) over session_partition_window as platform
        ,first_value(device_category) over session_partition_window as device_category
        ,first_value(device_mobile_brand_name) over session_partition_window as device_mobile_brand_name
        ,first_value(device_mobile_model_name) over session_partition_window as device_mobile_model_name
        ,first_value(device_mobile_marketing_name) over session_partition_window as device_mobile_marketing_name
        ,first_value(device_mobile_os_hardware_model) over session_partition_window as device_mobile_os_hardware_model
        ,first_value(device_operating_system) over session_partition_window as device_operating_system
        ,first_value(device_operating_system_version) over session_partition_window as device_operating_system_version
        ,first_value(device_vendor_id) over session_partition_window as device_vendor_id
        ,first_value(device_advertising_id) over session_partition_window as device_advertising_id
        ,first_value(device_language) over session_partition_window as device_language
        ,first_value(device_is_limited_ad_tracking) over session_partition_window as device_is_limited_ad_tracking
        ,first_value(device_time_zone_offset_seconds) over session_partition_window as device_time_zone_offset_seconds
        ,first_value(device_browser) over session_partition_window as device_browser
        ,first_value(device_web_info_browser) over session_partition_window as device_web_info_browser
        ,first_value(device_web_info_browser_version) over session_partition_window as device_web_info_browser_version
        ,first_value(device_web_info_hostname) over session_partition_window as device_web_info_hostname
        ,first_value(user_campaign) over session_partition_window as user_campaign
        ,first_value(user_medium) over session_partition_window as user_medium
        ,first_value(user_source) over session_partition_window as user_source
    from event_dimensions
    window session_partition_window as (partition by session_partition_key order by event_timestamp asc rows between unbounded preceding and unbounded following)
),
join_traffic_source as (
    select
        session_dimensions.*,
        session_source,
        session_medium,
        session_campaign,
        session_content,
        session_term,
        session_default_channel_grouping,
        session_source_category,
        last_non_direct_source,
        last_non_direct_medium,
        last_non_direct_campaign,
        last_non_direct_content,
        last_non_direct_term,
        last_non_direct_default_channel_grouping,
        last_non_direct_source_category
    from session_dimensions
    left join traffic_sources sessions_traffic_sources using (session_partition_key)
)

-- Collapse
select distinct * from join_traffic_source