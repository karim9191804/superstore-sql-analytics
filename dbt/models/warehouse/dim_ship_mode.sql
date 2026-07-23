with agg as (
    select distinct ship_mode
    from {{ ref('stg_superstore') }}
)

select
    row_number() over (order by ship_mode) as ship_mode_key,
    ship_mode
from agg
