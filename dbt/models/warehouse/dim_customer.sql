select
    customer_id,
    max(customer_name) as customer_name,
    max(segment) as segment
from {{ ref('stg_superstore') }}
group by customer_id
