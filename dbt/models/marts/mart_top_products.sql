with product_sales as (
    select
        category,
        sub_category,
        product_id,
        product_name,
        sum(sales) as total_sales,
        count(distinct order_id) as total_orders
    from {{ ref('stg_superstore') }}
    group by 1, 2, 3, 4
)

select
    category,
    sub_category,
    product_id,
    product_name,
    total_sales,
    total_orders,
    row_number() over (partition by category order by total_sales desc) as rank_in_category
from product_sales
qualify rank_in_category <= 10
order by category, rank_in_category
