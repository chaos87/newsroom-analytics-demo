{{ config(materialized='view') }}
{{ ga4.create_custom_event('bookmark') }}