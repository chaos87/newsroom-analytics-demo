with events_with_user_id as (
    select
        user_id,
        client_key,
        event_timestamp
    from {{ref('stg_ga4__events')}}
    where user_id is not null
        and client_key is not null
),
include_last_seen_timestamp as (
    select
        user_id,
        client_key,
        max(event_timestamp) as last_seen_user_id_timestamp
    from events_with_user_id
    group by 1,2
),
pick_latest_timestamp as (
    -- Find the latest mapping between client_key and user_id
    -- (Postgres port of upstream's qualify row_number() = 1)
    select distinct on (client_key)
        user_id as last_seen_user_id,
        client_key,
        last_seen_user_id_timestamp
    from include_last_seen_timestamp
    order by client_key, last_seen_user_id_timestamp desc
)

select * from pick_latest_timestamp