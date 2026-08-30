{#-
    Column selections for base_ga4__events.

    BigQuery upstream reads the daily-sharded events_* wildcard table where nested
    fields are STRUCTs (device.category, traffic_source.source, ...). On Postgres
    the export stores nested RECORDs as JSONB, so this port:
      * casts event_date ('YYYYMMDD' STRING, like the export) to a date
      * extracts struct fields with ->> (text) / -> (jsonb)
      * keeps the raw JSONB columns alongside, like the BQ schema keeps RECORDs
    Ecommerce / items struct paths are omitted (publisher site, no commerce) —
    the raw `ecommerce`, `items` and `item_params` JSONB columns are carried
    through unchanged instead.
-#}

{% macro base_select_source() %}
    to_date(event_date, 'YYYYMMDD') as event_date_dt
    , event_timestamp
    , event_name
    , event_params
    , event_previous_timestamp
    , event_value_in_usd
    , event_bundle_sequence_id
    , event_server_timestamp_offset
    , batch_event_index
    , batch_ordering_id
    , batch_page_id
    , is_active_user
    , user_id
    , user_pseudo_id
    , privacy_info
    , user_properties
    , user_first_touch_timestamp
    , user_ltv
    , device
    , geo
    , app_info
    , traffic_source
    , stream_id
    , platform
    , ecommerce
    , items
    , item_params
    , collected_traffic_source
    , {{ var('property_ids', [1])[0] }} as property_id
{% endmacro %}

{% macro base_select_renamed() %}
    event_date_dt
    , event_timestamp
    , lower(replace(trim(event_name), ' ', '_')) as event_name
    , event_params
    , event_previous_timestamp
    , event_value_in_usd
    , event_bundle_sequence_id
    , event_server_timestamp_offset
    , batch_event_index
    , batch_ordering_id
    , batch_page_id
    , is_active_user
    , user_id
    , user_pseudo_id
    , privacy_info->>'analytics_storage' as privacy_info_analytics_storage
    , privacy_info->>'ads_storage' as privacy_info_ads_storage
    , privacy_info->>'uses_transient_token' as privacy_info_uses_transient_token
    , user_properties
    , user_first_touch_timestamp
    , user_ltv->>'revenue' as user_ltv_revenue
    , user_ltv->>'currency' as user_ltv_currency
    , device->>'category' as device_category
    , device->>'mobile_brand_name' as device_mobile_brand_name
    , device->>'mobile_model_name' as device_mobile_model_name
    , device->>'mobile_marketing_name' as device_mobile_marketing_name
    , device->>'mobile_os_hardware_model' as device_mobile_os_hardware_model
    , device->>'operating_system' as device_operating_system
    , device->>'operating_system_version' as device_operating_system_version
    , device->>'vendor_id' as device_vendor_id
    , device->>'advertising_id' as device_advertising_id
    , device->>'language' as device_language
    , (device->>'is_limited_ad_tracking')::boolean as device_is_limited_ad_tracking
    , (device->>'time_zone_offset_seconds')::bigint as device_time_zone_offset_seconds
    , device->>'browser' as device_browser
    , device->>'browser_version' as device_browser_version
    , device->'web_info'->>'browser' as device_web_info_browser
    , device->'web_info'->>'browser_version' as device_web_info_browser_version
    , device->'web_info'->>'hostname' as device_web_info_hostname
    , geo->>'continent' as geo_continent
    , geo->>'country' as geo_country
    , geo->>'region' as geo_region
    , geo->>'city' as geo_city
    , geo->>'sub_continent' as geo_sub_continent
    , geo->>'metro' as geo_metro
    , app_info->>'id' as app_info_id
    , app_info->>'version' as app_info_version
    , app_info->>'install_source' as app_info_install_source
    , app_info->>'firebase_app_id' as app_info_firebase_app_id
    , traffic_source->>'name' as user_campaign
    , traffic_source->>'medium' as user_medium
    , traffic_source->>'source' as user_source
    , collected_traffic_source->>'manual_campaign_id' as collected_traffic_source_manual_campaign_id
    , collected_traffic_source->>'manual_campaign_name' as collected_traffic_source_manual_campaign_name
    , collected_traffic_source->>'manual_source' as collected_traffic_source_manual_source
    , collected_traffic_source->>'manual_medium' as collected_traffic_source_manual_medium
    , collected_traffic_source->>'manual_term' as collected_traffic_source_manual_term
    , collected_traffic_source->>'manual_content' as collected_traffic_source_manual_content
    , collected_traffic_source->>'manual_source_platform' as collected_traffic_source_manual_source_platform
    , collected_traffic_source->>'manual_creative_format' as collected_traffic_source_manual_creative_format
    , collected_traffic_source->>'manual_marketing_tactic' as collected_traffic_source_manual_marketing_tactic
    , collected_traffic_source->>'gclid' as collected_traffic_source_gclid
    , collected_traffic_source->>'dclid' as collected_traffic_source_dclid
    , collected_traffic_source->>'srsltid' as collected_traffic_source_srsltid
    , stream_id
    , platform
    , ecommerce
    , items
    , item_params
    , property_id
    , {{ ga4.unnest_key('event_params', 'ga_session_id', 'int_value', 'session_id') }}
    , {{ ga4.unnest_key('event_params', 'page_location') }}
    , {{ ga4.unnest_key('event_params', 'ga_session_number', 'int_value', 'session_number') }}
    , coalesce(
        (select (ep->'value'->>'int_value')::bigint
         from jsonb_array_elements(event_params) ep
         where ep->>'key' = 'session_engaged')
        , case
            when (select ep->'value'->>'string_value'
                  from jsonb_array_elements(event_params) ep
                  where ep->>'key' = 'session_engaged') = '1' then 1
          end
      ) as session_engaged
    , {{ ga4.unnest_key('event_params', 'engagement_time_msec', 'int_value') }}
    , {{ ga4.unnest_key('event_params', 'page_title') }}
    , {{ ga4.unnest_key('event_params', 'page_referrer') }}
    , {{ ga4.unnest_key('event_params', 'source', 'lower_string_value', 'event_source') }}
    , {{ ga4.unnest_key('event_params', 'medium', 'lower_string_value', 'event_medium') }}
    , {{ ga4.unnest_key('event_params', 'campaign', 'lower_string_value', 'event_campaign') }}
    , {{ ga4.unnest_key('event_params', 'content', 'lower_string_value', 'event_content') }}
    , {{ ga4.unnest_key('event_params', 'term', 'lower_string_value', 'event_term') }}
    , case when event_name = 'page_view' then 1 else 0 end as is_page_view
    , case when event_name = 'purchase' then 1 else 0 end as is_purchase
{% endmacro %}