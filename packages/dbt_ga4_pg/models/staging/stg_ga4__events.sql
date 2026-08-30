-- This staging model contains key creation and window functions. Keeping window
-- functions outside of the base incremental model ensures that the incremental
-- updates don't artificially limit the window partition sizes (ex: if a session
-- spans 2 days, but only 1 day is in the incremental update)
--
-- Postgres port notes:
--   to_base64(md5(x))  → md5(x)  (hex instead of base64 — keys stay stable)
--   BQ concat() skips NULL args; Postgres || / concat_ws() need explicit handling
--   so that a NULL user_pseudo_id still yields a NULL client_key (consent denied).

with base_events as (
    select * from {{ ref('base_ga4__events') }}
),
include_client_key as (
    select
        *
        , case
            when user_pseudo_id is null then null
            else md5(user_pseudo_id || stream_id)
          end as client_key
    from base_events
),
include_session_key as (
    select
        *
        , md5(client_key || session_id::text) as session_key
    from include_client_key
),
include_session_partition_key as (
    select
        *
        , session_key || event_date_dt::text as session_partition_key
    from include_session_key
),
include_event_key as (
    select
        *
        , md5(concat_ws('',
            client_key,
            session_id::text,
            event_name,
            event_timestamp::text,
            event_params::text
        )) as event_key
    from include_session_partition_key
),
detect_gclid as (
    select
        event_date_dt, event_timestamp, event_name, event_params,
        event_previous_timestamp, event_value_in_usd, event_bundle_sequence_id,
        event_server_timestamp_offset, batch_event_index, batch_ordering_id,
        batch_page_id, is_active_user, user_id, user_pseudo_id,
        privacy_info_analytics_storage, privacy_info_ads_storage, privacy_info_uses_transient_token,
        user_properties, user_first_touch_timestamp, user_ltv_revenue, user_ltv_currency,
        device_category, device_mobile_brand_name, device_mobile_model_name,
        device_mobile_marketing_name, device_mobile_os_hardware_model,
        device_operating_system, device_operating_system_version, device_vendor_id,
        device_advertising_id, device_language, device_is_limited_ad_tracking,
        device_time_zone_offset_seconds, device_browser, device_browser_version,
        device_web_info_browser, device_web_info_browser_version, device_web_info_hostname,
        geo_continent, geo_country, geo_region, geo_city, geo_sub_continent, geo_metro,
        app_info_id, app_info_version, app_info_install_source, app_info_firebase_app_id,
        user_campaign, user_medium, user_source,
        collected_traffic_source_manual_campaign_id, collected_traffic_source_manual_campaign_name,
        collected_traffic_source_manual_source, collected_traffic_source_manual_medium,
        collected_traffic_source_manual_term, collected_traffic_source_manual_content,
        collected_traffic_source_manual_source_platform, collected_traffic_source_manual_creative_format,
        collected_traffic_source_manual_marketing_tactic, collected_traffic_source_gclid,
        collected_traffic_source_dclid, collected_traffic_source_srsltid,
        stream_id, platform, ecommerce, items, item_params, property_id,
        session_id, page_location, session_number, session_engaged,
        engagement_time_msec, page_title, page_referrer, event_content, event_term,
        is_page_view, is_purchase, event_key, client_key, session_key,
        session_partition_key,
        case
            when (page_location like '%gclid%' and event_source is null) then 'google'
            else event_source
        end as event_source,
        case
            when (page_location like '%gclid%' and event_medium is null) then 'cpc'
            when (page_location like '%gclid%' and event_medium = 'organic') then 'cpc'
            else event_medium
        end as event_medium,
        case
            when (page_location like '%gclid%' and event_campaign is null) then '(cpc)'
            when (page_location like '%gclid%' and event_campaign = 'organic') then '(cpc)'
            when (page_location like '%gclid%' and event_campaign = '(organic)') then '(cpc)'
            else event_campaign
        end as event_campaign
    from include_event_key
),
remove_query_params as (
    select
        event_date_dt, event_timestamp, event_name, event_params,
        event_previous_timestamp, event_value_in_usd, event_bundle_sequence_id,
        event_server_timestamp_offset, batch_event_index, batch_ordering_id,
        batch_page_id, is_active_user, user_id, user_pseudo_id,
        privacy_info_analytics_storage, privacy_info_ads_storage, privacy_info_uses_transient_token,
        user_properties, user_first_touch_timestamp, user_ltv_revenue, user_ltv_currency,
        device_category, device_mobile_brand_name, device_mobile_model_name,
        device_mobile_marketing_name, device_mobile_os_hardware_model,
        device_operating_system, device_operating_system_version, device_vendor_id,
        device_advertising_id, device_language, device_is_limited_ad_tracking,
        device_time_zone_offset_seconds, device_browser, device_browser_version,
        device_web_info_browser, device_web_info_browser_version, device_web_info_hostname,
        geo_continent, geo_country, geo_region, geo_city, geo_sub_continent, geo_metro,
        app_info_id, app_info_version, app_info_install_source, app_info_firebase_app_id,
        user_campaign, user_medium, user_source,
        collected_traffic_source_manual_campaign_id, collected_traffic_source_manual_campaign_name,
        collected_traffic_source_manual_source, collected_traffic_source_manual_medium,
        collected_traffic_source_manual_term, collected_traffic_source_manual_content,
        collected_traffic_source_manual_source_platform, collected_traffic_source_manual_creative_format,
        collected_traffic_source_manual_marketing_tactic, collected_traffic_source_gclid,
        collected_traffic_source_dclid, collected_traffic_source_srsltid,
        stream_id, platform, ecommerce, items, item_params, property_id,
        session_id, session_number, session_engaged, page_title,
        engagement_time_msec, event_source, event_medium, event_campaign, event_content, event_term,
        is_page_view, is_purchase, event_key, client_key, session_key, session_partition_key,
        page_location as original_page_location,
        page_referrer as original_page_referrer,
        {{ extract_page_path('page_location') }} as page_path,
        -- If there are query parameters to exclude, exclude them using regex
        {% if var('query_parameter_exclusions', none) is not none %}
        {{ remove_query_parameters('page_location', var('query_parameter_exclusions')) }} as page_location,
        {{ remove_query_parameters('page_referrer', var('query_parameter_exclusions')) }} as page_referrer
        {% else %}
        page_location,
        page_referrer
        {% endif %}
    from detect_gclid
),
enrich_params as (
    select
        *
        , {{ extract_hostname_from_url('page_location') }} as page_hostname
        , {{ extract_query_string_from_url('page_location') }} as page_query_string
    from remove_query_params
),
page_key as (
    select
        *
        , (event_date_dt::text || page_location) as page_key
    from enrich_params
)
select * from page_key