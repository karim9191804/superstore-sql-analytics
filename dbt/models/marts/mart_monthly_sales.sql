with monthly as (
    select
        date_trunc('month', order_date)::date as month,
        sum(sales) as total_sales,
        count(distinct order_id) as total_orders
    from {{ ref('stg_superstore') }}
    group by 1
)

select
    month,
    total_sales,
    total_orders,
    sum(total_sales) over (
        order by month
        rows between unbounded preceding and current row
    ) as cumulative_sales,
    round(
        (total_sales - lag(total_sales) over (order by month))
        / nullif(lag(total_sales) over (order by month), 0) * 100
    , 2) as mom_growth_pct
from monthly
order by month
