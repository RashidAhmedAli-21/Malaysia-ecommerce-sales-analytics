# Power BI Build Guide

Follow these steps to build the dashboard yourself in **Power BI Desktop** (free, Windows). It takes about 2–3 hours.
The target layout is in `images/dashboard_mockup.png`.

---

## Step 1: Load the data

**Option A, CSV (easiest):** Home → Get Data → Text/CSV, then load all three files from `data/clean/`:
- `fact_sales.csv`
- `dim_customer.csv`
- `dim_product.csv`

**Option B, MySQL (looks better on your CV):** Home → Get Data → MySQL database
→ Server: `localhost`, Database: `malaysia_ecommerce` → select `vw_fact_sales`, `vw_dim_customer`, `vw_dim_product`.
(You may need to install the MySQL Connector/NET first. Power BI will prompt you.)

In Power Query, check the data types: `order_date` = Date; revenue, cost and profit columns = Decimal Number.

## Step 2: Create a date table

Modeling → New Table:

```DAX
dim_date =
ADDCOLUMNS (
    CALENDAR ( DATE ( 2024, 1, 1 ), DATE ( 2025, 12, 31 ) ),
    "Year", YEAR ( [Date] ),
    "Month Num", MONTH ( [Date] ),
    "Month", FORMAT ( [Date], "MMM" ),
    "Year-Month", FORMAT ( [Date], "YYYY-MM" )
)
```

Then: select the table → Table tools → **Mark as date table** → choose `Date`.
Sort the `Month` column by `Month Num` (Column tools → Sort by column).

## Step 3: Build the star schema (Model view)

Create these relationships (all many-to-one, single direction):

| From (many)                 | To (one)                    |
|-----------------------------|-----------------------------|
| fact_sales[order_date]      | dim_date[Date]              |
| fact_sales[customer_id]     | dim_customer[customer_id]   |
| fact_sales[product_id]      | dim_product[product_id]     |

Take a screenshot of this Model view. It goes in your GitHub README.

## Step 4: DAX measures

Create a blank table called `_Measures` (Home → Enter Data → OK) and add these measures:

```DAX
Total Revenue =
CALCULATE ( SUM ( fact_sales[net_revenue] ), fact_sales[order_status] = "Completed" )

Total Profit =
CALCULATE ( SUM ( fact_sales[profit] ), fact_sales[order_status] = "Completed" )

Profit Margin % =
DIVIDE ( [Total Profit], [Total Revenue] )

Orders =
CALCULATE ( DISTINCTCOUNT ( fact_sales[order_id] ), fact_sales[order_status] = "Completed" )

Avg Order Value =
DIVIDE ( [Total Revenue], [Orders] )

Revenue LY =
CALCULATE ( [Total Revenue], SAMEPERIODLASTYEAR ( dim_date[Date] ) )

YoY Growth % =
DIVIDE ( [Total Revenue] - [Revenue LY], [Revenue LY] )

Cancellation Rate % =
DIVIDE (
    CALCULATE ( DISTINCTCOUNT ( fact_sales[order_id] ), fact_sales[order_status] = "Cancelled" ),
    DISTINCTCOUNT ( fact_sales[order_id] )
)

Repeat Customers =
COUNTROWS (
    FILTER (
        VALUES ( fact_sales[customer_id] ),
        CALCULATE ( DISTINCTCOUNT ( fact_sales[order_id] ), fact_sales[order_status] = "Completed" ) > 1
    )
)
```

Format: revenue measures as currency (RM), % measures as Percentage with 1 decimal.

## Step 5: Build the pages

### Page 1: Executive Overview
- **5 KPI cards:** Total Revenue, Profit Margin %, Orders, Avg Order Value, YoY Growth %
- **Line chart:** X = dim_date[Year-Month], Y = Total Revenue
- **Bar chart:** Y = dim_product[category_name], X = Total Revenue
- **Filled map** (or bar chart): Location = dim_customer[state_name], Value = Total Revenue
- **Slicers:** dim_date[Year], dim_customer[region_name], dim_product[category_name]

### Page 2: Customers & Payments
- **Bar chart:** payment_method vs Cancellation Rate % (conditional formatting: red if > 10%)
- **Column chart:** dim_customer[age_group] vs Avg Order Value
- **Card:** Repeat Customers
- **Table:** top 10 customers by Total Revenue (use Top N filter)

### Page 3: Products
- **Bar chart:** top 10 product_name by Total Revenue (Top N filter)
- **Matrix:** category_name → product_name, with Total Revenue, Total Profit, Profit Margin %

## Step 6: Polish and publish
- Use one colour theme (View → Themes). Navy `#1f3a5f` and blue `#3b78b8` match the mockup.
- Add a title text box on every page.
- Save as `dashboard/Malaysia_Ecommerce_Dashboard.pbix`.
- Export screenshots of each page into `images/`, then replace the mockup image in the README with your real screenshots.
- Optional: File → Publish to web (needs a work/school account) and put the link in your README and CV.

## Check your numbers

Your Page 1 cards should match the SQL results:

| Measure | Expected |
|---|---|
| Total Revenue | RM 1,395,314 |
| Profit Margin % | 37.1% |
| Orders | 5,323 |
| Avg Order Value | RM 262.13 |
| YoY Growth % (2025) | 20.6% |
| Cancellation rate, Cash on Delivery | 18.3% |

If they match, your model and DAX are correct.
