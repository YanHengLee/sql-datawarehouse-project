/*
=====================================================================================
Product Report
=====================================================================================
Purpose:
	- This report consolidates key product metrics and behaviours.

Highlights:
	1. Gather essential fields such as product name, category, subcategory, and cost.
	2. Segment products by revenue to identify High-performers, Mid-range, or Low-performers.
	3. Aggregates product-level metrics:
		- total orders
		- total sales
		- total quantity sold
		- total customer (unique)
		- lifespan (in months)
	4. Calculates valuable KPIs:
		- recency (months since last sale)
		- average order value (AOR)
		- average monthly revenue
=====================================================================================
*/

CREATE VIEW gold.report_products AS
/*-----------------------------------------------------------------------------------
1) Base Query: Retrieve core columns from tables
-----------------------------------------------------------------------------------*/
WITH base_query AS
(
	SELECT
		f.order_number,
		f.customer_key,
		f.order_date,
		f.sales_amount,
		f.quantity,
		p.product_key,
		p.product_name,
		p.category,
		p.subcategory,
		p.cost
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p
	ON f.product_key = p.product_key
	WHERE order_date IS NOT NULL
)
/*-----------------------------------------------------------------------------------
2) Product Aggregations: Summarizes key metrics at the product level
-----------------------------------------------------------------------------------*/
, product_aggregation AS
(
	SELECT
		product_key,
		product_name,
		category,
		subcategory,
		cost,
		COUNT(DISTINCT order_number) AS total_orders,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS total_quantity_sold,
		COUNT(DISTINCT customer_key) AS total_customer,
		MAX(order_date) AS last_sale_date,
		DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
		ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)), 1) AS avg_selling_price
	FROM base_query
	GROUP BY
		product_key,
		product_name,
		category,
		subcategory,
		cost
)
/*-----------------------------------------------------------------------------------
3) Final Query: Combines all product results into one output
-----------------------------------------------------------------------------------*/
SELECT
	product_name,
	category,
	subcategory,
	cost,
	last_sale_date,
	DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_in_months,
	CASE WHEN total_sales > 50000 THEN 'High Performers'
		 WHEN total_sales >= 10000 THEN 'Mid-rangers'
		 ELSE 'Low Performers'
	END AS product_segement,
	total_orders,
	total_sales,
	total_quantity_sold,
	avg_selling_price,
	total_customer,
	lifespan,
	-- Compute average order value (AVO)
	CASE WHEN total_sales = 0 THEN 0
		 ELSE total_sales / total_orders
	END  AS avg_order_revenue,
	-- Compute average monthly spending
	CASE WHEN lifespan = 0 THEN total_sales
		 ELSE total_sales / lifespan
	END AS avg_monthly_revenue
FROM product_aggregation
