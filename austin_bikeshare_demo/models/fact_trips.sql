SELECT
    trip_id,
    subscriber_type,
    bike_id,
    bike_type,
    start_time,
    start_station_id,
    start_station_name,
    cast(end_station_id AS INTEGER) AS end_station_id,
    end_station_name,
    duration_minutes
FROM {{ source('austin_bikeshare', 'bikeshare_trips') }}
WHERE REGEXP_CONTAINS(CAST(end_station_id AS STRING), r'^-?\d+(\.\d+)?$')
AND start_station_id IS NOT NULL
AND end_station_id IS NOT NULL