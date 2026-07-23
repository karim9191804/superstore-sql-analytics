with monthly as (
    select
        make_date(d.year, d.month, 1) as month,
        sum(f.sales) as total_sales,
        count(distinct f.order_id) as total_orders
    from {{ ref('fact_sales') }} f
    join {{ ref('dim_date') }} d on f.order_date_key = d.date_key
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
