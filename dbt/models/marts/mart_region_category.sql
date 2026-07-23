with agg as (
    select
        region,
        category,
        sum(sales) as total_sales,
        count(distinct order_id) as total_orders,
        count(distinct customer_id) as total_customers
    from {{ ref('stg_superstore') }}
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
