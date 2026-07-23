select
    s.row_id,
    s.order_id,
    s.customer_id,
    s.product_id,
    s.order_date,
    s.ship_date,
    s.ship_mode,
    l.location_id,
    s.sales
from {{ ref('stg_superstore') }} s
left join {{ ref('dim_location') }} l
    on s.city = l.city
    and s.state = l.state
    and s.postal_code is not distinct from l.postal_code
    and s.region = l.region
    and s.country = l.country
