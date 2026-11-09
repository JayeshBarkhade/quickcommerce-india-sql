-- Q1. Monthly orders, revenue (GMV), average order value, active customers and month-over-month growth.
-- Skills: DATE_TRUNC, CTE, LAG() window, running total with SUM() OVER, COUNT(DISTINCT).
-- Demand lifts show up around Holi (March) and Diwali (October) in this dataset.
WITH monthly AS (
  SELECT date_trunc('month', order_ts)::date AS month, count(*) AS orders, count(DISTINCT customer_id) AS active_customers,
         sum(amount_paid) AS gmv, avg(amount_paid) AS aov
  FROM qc.v_delivered_orders GROUP BY 1)
SELECT month, orders, active_customers, round(gmv, 0) AS gmv_rs, round(aov, 0) AS avg_order_value_rs,
       round(100.0 * (gmv - LAG(gmv) OVER w) / NULLIF(LAG(gmv) OVER w, 0), 1) AS mom_growth_pct,
       round(sum(gmv) OVER (ORDER BY month), 0) AS cumulative_gmv_rs
FROM monthly WINDOW w AS (ORDER BY month) ORDER BY month;
