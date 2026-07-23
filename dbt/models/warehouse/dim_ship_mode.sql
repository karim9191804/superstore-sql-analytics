select distinct
    ship_mode
from {{ ref('stg_superstore') }}
