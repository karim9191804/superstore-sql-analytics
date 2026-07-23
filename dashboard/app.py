import shutil
import subprocess
import sys
from pathlib import Path

import duckdb
import pandas as pd
import plotly.express as px
import streamlit as st

DBT_DIR = Path(__file__).resolve().parent.parent / "dbt"
DB_PATH = DBT_DIR / "superstore.duckdb"

st.set_page_config(page_title="Superstore Sales Analytics", layout="wide", page_icon="📊")


def _resolve_dbt_executable() -> str:
    """Find the dbt entrypoint even when the venv's bin/Scripts dir isn't on PATH."""
    found = shutil.which("dbt")
    if found:
        return found
    exe_dir = Path(sys.executable).parent
    for candidate in (exe_dir / "dbt", exe_dir / "dbt.exe", exe_dir / "Scripts" / "dbt.exe"):
        if candidate.exists():
            return str(candidate)
    return "dbt"


def ensure_database_built():
    """(Re)build the DuckDB warehouse via dbt.

    Always rebuilds rather than skipping when DB_PATH already exists: a
    schema change (e.g. renaming columns) can leave a stale file behind
    on a persistent deploy target, and dbt build is cheap (~1-2s) since
    models are tables (create-or-replace), so there's no benefit to
    trying to detect "already up to date" instead of just rebuilding.
    """
    with st.spinner("Construction de l'entrepôt de données (dbt build)…"):
        result = subprocess.run(
            [_resolve_dbt_executable(), "build", "--profiles-dir", ".", "--project-dir", "."],
            cwd=str(DBT_DIR),
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            st.error("Échec de `dbt build` :\n\n" + result.stdout[-3000:] + result.stderr[-1000:])
            st.stop()


@st.cache_resource
def get_connection():
    # @st.cache_resource guarantees this runs exactly once per server process
    # (internally lock-protected), so the dbt build can't race across reruns/sessions.
    ensure_database_built()
    return duckdb.connect(str(DB_PATH), read_only=True)


@st.cache_data
def load_filter_bounds():
    con = get_connection()
    bounds = con.execute(
        """
        select min(d.date_day), max(d.date_day)
        from fact_sales f
        join dim_date d on f.order_date_key = d.date_key
        """
    ).fetchone()
    regions = [r[0] for r in con.execute(
        "select distinct region from dim_location order by 1"
    ).fetchall()]
    categories = [c[0] for c in con.execute(
        "select distinct category from dim_product order by 1"
    ).fetchall()]
    return bounds[0], bounds[1], regions, categories


@st.cache_data
def query_filtered(start_date, end_date, regions, categories):
    con = get_connection()
    # fact_sales joined to its dimensions via integer surrogate FK -> PK, star-schema style
    base_from = """
        from fact_sales f
        join dim_location l on f.location_key = l.location_key
        join dim_product p on f.product_key = p.product_key
        join dim_date d on f.order_date_key = d.date_key
    """
    where = """
        where d.date_day between ? and ?
        and l.region in ({})
        and p.category in ({})
    """.format(
        ",".join(["?"] * len(regions)),
        ",".join(["?"] * len(categories)),
    )
    params = [start_date, end_date, *regions, *categories]

    kpis = con.execute(
        f"""
        select
            sum(f.sales) as total_sales,
            count(distinct f.order_id) as total_orders,
            count(distinct f.customer_key) as total_customers,
            sum(f.sales) / nullif(count(distinct f.order_id), 0) as avg_order_value
        {base_from}
        {where}
        """,
        params,
    ).fetchdf()

    monthly = con.execute(
        f"""
        with monthly as (
            select date_trunc('month', d.date_day)::date as month, sum(f.sales) as total_sales
            {base_from}
            {where}
            group by 1
        )
        select
            month,
            total_sales,
            sum(total_sales) over (order by month rows between unbounded preceding and current row) as cumulative_sales
        from monthly
        order by month
        """,
        params,
    ).fetchdf()

    region_cat = con.execute(
        f"""
        select l.region, p.category, sum(f.sales) as total_sales
        {base_from}
        {where}
        group by 1, 2
        order by 1, 2
        """,
        params,
    ).fetchdf()

    top_products = con.execute(
        f"""
        select p.product_name, p.category, sum(f.sales) as total_sales
        {base_from}
        {where}
        group by 1, 2
        order by total_sales desc
        limit 10
        """,
        params,
    ).fetchdf()

    return kpis, monthly, region_cat, top_products


@st.cache_data
def load_marts():
    con = get_connection()
    customer_summary = con.execute("select * from mart_customer_summary").fetchdf()
    shipping = con.execute("select * from mart_shipping_performance").fetchdf()
    return customer_summary, shipping


st.title("📊 Superstore Sales Analytics")
st.caption(
    "Dashboard interactif propulsé par SQL/DuckDB + dbt — "
    "toutes les métriques ci-dessous sont calculées via des requêtes SQL "
    "(agrégations, CTE, window functions) sur les données de ventes."
)

min_date, max_date, all_regions, all_categories = load_filter_bounds()

with st.sidebar:
    st.header("Filtres")
    date_range = st.date_input(
        "Période", value=(min_date, max_date), min_value=min_date, max_value=max_date
    )
    selected_regions = st.multiselect("Région", all_regions, default=all_regions)
    selected_categories = st.multiselect("Catégorie", all_categories, default=all_categories)

if len(date_range) != 2:
    st.stop()

start_date, end_date = date_range
if not selected_regions or not selected_categories:
    st.warning("Sélectionne au moins une région et une catégorie.")
    st.stop()

kpis, monthly, region_cat, top_products = query_filtered(
    start_date, end_date, selected_regions, selected_categories
)
customer_summary, shipping = load_marts()

k = kpis.iloc[0]
col1, col2, col3, col4 = st.columns(4)
col1.metric("Ventes totales", f"${k['total_sales']:,.0f}")
col2.metric("Commandes", f"{int(k['total_orders']):,}")
col3.metric("Clients", f"{int(k['total_customers']):,}")
col4.metric("Panier moyen", f"${k['avg_order_value']:,.2f}")

st.divider()

col_left, col_right = st.columns(2)

with col_left:
    st.subheader("Tendance mensuelle des ventes (cumul)")
    fig = px.line(monthly, x="month", y=["total_sales", "cumulative_sales"], markers=True)
    fig.update_layout(legend_title_text="", xaxis_title="Mois", yaxis_title="Ventes ($)")
    st.plotly_chart(fig, use_container_width=True)

with col_right:
    st.subheader("Ventes par région et catégorie")
    fig = px.bar(region_cat, x="region", y="total_sales", color="category", barmode="group")
    fig.update_layout(xaxis_title="Région", yaxis_title="Ventes ($)")
    st.plotly_chart(fig, use_container_width=True)

col_left2, col_right2 = st.columns(2)

with col_left2:
    st.subheader("Top 10 produits (période filtrée)")
    st.dataframe(top_products, use_container_width=True, hide_index=True)

with col_right2:
    st.subheader("Segmentation clients (RFM)")
    seg_counts = customer_summary["customer_segment"].value_counts().reset_index()
    seg_counts.columns = ["segment", "clients"]
    fig = px.pie(seg_counts, names="segment", values="clients", hole=0.4)
    st.plotly_chart(fig, use_container_width=True)

st.divider()
st.subheader("Performance logistique par mode d'expédition")
st.dataframe(
    shipping.sort_values("avg_ship_delay_days"),
    use_container_width=True,
    hide_index=True,
)

with st.expander("Voir le détail RFM par client"):
    st.dataframe(customer_summary, use_container_width=True, hide_index=True)
