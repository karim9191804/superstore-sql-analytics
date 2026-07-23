with product_sales as (
    select
        p.category,
        p.sub_category,
        p.product_id,
        p.product_name,
        sum(f.sales) as total_sales,
        count(distinct f.order_id) as total_orders
    from {{ ref('fact_sales') }} f
    join {{ ref('dim_product') }} p on f.product_key = p.product_key
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
