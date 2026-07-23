with distinct_locations as (
    select distinct
        city,
        state,
        postal_code,
        region,
        country
    from {{ ref('stg_superstore') }}
)

select
    row_number() over (order by country, region, state, city, postal_code) as location_id,
    city,
    state,
    postal_code,
    region,
    country
from distinct_locations
