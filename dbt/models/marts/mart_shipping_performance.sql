with shipping as (
    select
        sm.ship_mode,
        l.region,
        date_diff('day', od.date_day, sd.date_day) as ship_delay_days,
        f.sales
    from {{ ref('fact_sales') }} f
    join {{ ref('dim_location') }} l on f.location_key = l.location_key
    join {{ ref('dim_ship_mode') }} sm on f.ship_mode_key = sm.ship_mode_key
    join {{ ref('dim_date') }} od on f.order_date_key = od.date_key
    join {{ ref('dim_date') }} sd on f.ship_date_key = sd.date_key
)

select
    ship_mode,
    region,
    count(*) as total_orders,
    round(avg(ship_delay_days), 2) as avg_ship_delay_days,
    min(ship_delay_days) as min_ship_delay_days,
    max(ship_delay_days) as max_ship_delay_days,
    sum(sales) as total_sales
from shipping
group by 1, 2
order by ship_mode, region
