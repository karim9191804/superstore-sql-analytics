with shipping as (
    select
        ship_mode,
        region,
        date_diff('day', order_date, ship_date) as ship_delay_days,
        sales
    from {{ ref('stg_superstore') }}
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
