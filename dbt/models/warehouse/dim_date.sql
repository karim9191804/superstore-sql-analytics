with bounds as (
    select
        least(min(order_date), min(ship_date)) as min_date,
        greatest(max(order_date), max(ship_date)) as max_date
    from {{ ref('stg_superstore') }}
),

spine as (
    select date_day::date as date_day
    from bounds, generate_series(bounds.min_date, bounds.max_date, interval 1 day) as t(date_day)
)

select
    date_day,
    extract(year from date_day) as year,
    extract(quarter from date_day) as quarter,
    extract(month from date_day) as month,
    extract(day from date_day) as day,
    dayname(date_day) as day_name,
    extract(dow from date_day) as day_of_week,
    extract(isoyear from date_day) as iso_year,
    extract(week from date_day) as iso_week
from spine
