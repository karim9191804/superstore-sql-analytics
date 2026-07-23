select
    s.row_id,
    s.order_id,
    c.customer_key,
    p.product_key,
    l.location_key,
    sm.ship_mode_key,
    od.date_key as order_date_key,
    sd.date_key as ship_date_key,
    s.sales
from {{ ref('stg_superstore') }} s
join {{ ref('dim_customer') }} c on s.customer_id = c.customer_id
join {{ ref('dim_product') }} p on s.product_id = p.product_id
left join {{ ref('dim_location') }} l
    on s.city = l.city
    and s.state = l.state
    and s.postal_code is not distinct from l.postal_code
    and s.region = l.region
    and s.country = l.country
join {{ ref('dim_ship_mode') }} sm on s.ship_mode = sm.ship_mode
join {{ ref('dim_date') }} od on s.order_date = od.date_day
join {{ ref('dim_date') }} sd on s.ship_date = sd.date_day
