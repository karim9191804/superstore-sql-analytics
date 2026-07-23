select
    product_id,
    max(product_name) as product_name,
    max(category) as category,
    max(sub_category) as sub_category
from {{ ref('stg_superstore') }}
group by product_id
