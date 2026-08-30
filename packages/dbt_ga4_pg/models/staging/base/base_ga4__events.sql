{#-
    Base events model — Postgres port of the upstream BigQuery model.

    Upstream (BQ): materialized as an incremental, date-partitioned table because
    BigQuery wildcard scans over events_* shards are expensive; the model also
    dedupes with qualify row_number() over the event identity tuple.

    Port (PG): materialized as a VIEW. On Postgres the export already lands in a
    single natively-partitioned table (events_YYYYMMDD partitions), which gives
    us the partition management the BQ base model exists for — and Neon's storage
    budget makes a full flattened copy of the events table a luxury we don't
    need. The dedup logic is identical: row_number() = 1 over the upstream
    identity tuple (event_date, stream, client, session, name, timestamp, sorted
    event_params payload). The GA4 late-arrival behaviour (3-day reprocess
    window) is implemented by the incremental *_daily mart models.
-#}
{{ config(materialized = 'view') }}

with source as (
    select
        {{ ga4.base_select_source() }}
    from {{ source('ga4', 'events') }}
    where event_date >= '{{ var('start_date') }}'
),
renamed as (
    select
        {{ ga4.base_select_renamed() }}
    from source
),
ranked as (
    select
        *
        , row_number() over (
            partition by
                event_date_dt
                , stream_id
                , user_pseudo_id
                , session_id
                , event_name
                , event_timestamp
                , (select jsonb_agg(ep order by ep->>'key')
                   from jsonb_array_elements(event_params) ep)
        ) as rn
    from renamed
)

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
    engagement_time_msec, page_title, page_referrer,
    event_source, event_medium, event_campaign, event_content, event_term,
    is_page_view, is_purchase
from ranked
where rn = 1