with agg as (
    select
        product_id,
        max(product_name) as product_name,
        max(category) as category,
        max(sub_category) as sub_category
    from {{ ref('stg_superstore') }}
    group by product_id
)

select
    row_number() over (order by product_id) as product_key,
    product_id,
    product_name,
    category,
    sub_category
from agg
