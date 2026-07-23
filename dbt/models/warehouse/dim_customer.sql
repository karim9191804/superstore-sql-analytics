with agg as (
    select
        customer_id,
        max(customer_name) as customer_name,
        max(segment) as segment
    from {{ ref('stg_superstore') }}
    group by customer_id
)

select
    row_number() over (order by customer_id) as customer_key,
    customer_id,
    customer_name,
    segment
from agg
