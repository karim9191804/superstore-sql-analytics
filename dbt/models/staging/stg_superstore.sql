with source as (
    select * from {{ source('raw', 'superstore') }}
),

renamed as (
    select
        "Row_ID"::integer as row_id,
        "Order_ID"::varchar as order_id,
        "Order_Date"::date as order_date,
        "Ship_Date"::date as ship_date,
        "Ship_Mode"::varchar as ship_mode,
        "Customer_ID"::varchar as customer_id,
        trim("Customer_Name")::varchar as customer_name,
        "Segment"::varchar as segment,
        "Country"::varchar as country,
        "City"::varchar as city,
        "State"::varchar as state,
        "Postal_Code"::varchar as postal_code,
        "Region"::varchar as region,
        "Product_ID"::varchar as product_id,
        "Category"::varchar as category,
        "Sub_Category"::varchar as sub_category,
        trim("Product_Name")::varchar as product_name,
        "Sales"::double as sales
    from source
),

deduped as (
    select
        *,
        row_number() over (partition by row_id order by row_id) as rn
    from renamed
)

select
    row_id,
    order_id,
    order_date,
    ship_date,
    ship_mode,
    customer_id,
    customer_name,
    segment,
    country,
    city,
    state,
    postal_code,
    region,
    product_id,
    category,
    sub_category,
    product_name,
    sales
from deduped
where rn = 1
