with orders as (
    select
        c.customer_id,
        c.customer_name,
        c.segment,
        f.order_id,
        od.date_day as order_date,
        f.sales
    from {{ ref('fact_sales') }} f
    join {{ ref('dim_customer') }} c on f.customer_key = c.customer_key
    join {{ ref('dim_date') }} od on f.order_date_key = od.date_key
),

customer_orders as (
    select
        customer_id,
        max(customer_name) as customer_name,
        max(segment) as segment,
        count(distinct order_id) as frequency,
        sum(sales) as monetary,
        max(order_date) as last_order_date
    from orders
    group by 1
),

with_recency as (
    select
        *,
        date_diff('day', last_order_date, (select max(order_date) from orders)) as recency_days
    from customer_orders
),

scored as (
    select
        *,
        ntile(4) over (order by recency_days asc) as recency_score,
        ntile(4) over (order by frequency desc) as frequency_score,
        ntile(4) over (order by monetary desc) as monetary_score
    from with_recency
)

select
    customer_id,
    customer_name,
    segment,
    frequency,
    monetary,
    last_order_date,
    recency_days,
    recency_score,
    frequency_score,
    monetary_score,
    case
        when recency_score = 1 and frequency_score = 1 and monetary_score = 1 then 'Champion'
        when monetary_score <= 2 and frequency_score <= 2 then 'Client fidèle'
        when recency_score >= 3 then 'À risque'
        else 'Standard'
    end as customer_segment
from scored
order by monetary desc
