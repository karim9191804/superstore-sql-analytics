with agg as (
    select
        l.region,
        p.category,
        sum(f.sales) as total_sales,
        count(distinct f.order_id) as total_orders,
        count(distinct f.customer_id) as total_customers
    from {{ ref('fact_sales') }} f
    join {{ ref('dim_location') }} l on f.location_id = l.location_id
    join {{ ref('dim_product') }} p on f.product_id = p.product_id
    group by 1, 2
)

select
    region,
    category,
    total_sales,
    total_orders,
    total_customers,
    rank() over (partition by region order by total_sales desc) as category_rank_in_region,
    round(100 * total_sales / sum(total_sales) over (partition by region), 2) as pct_of_region_sales
from agg
order by region, category_rank_in_region
