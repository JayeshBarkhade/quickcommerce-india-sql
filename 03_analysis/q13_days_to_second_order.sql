-- Q13. How soon after the first order does a repeat customer order again? Tells us WHEN to nudge a new customer.
-- Skills: ROW_NUMBER() and LAG() over one named window, percentile aggregates.
WITH seq AS (
  SELECT customer_id, order_ts, ROW_NUMBER() OVER w AS order_no, LAG(order_ts) OVER w AS prev_ts
  FROM qc.v_delivered_orders
  WINDOW w AS (PARTITION BY customer_id ORDER BY order_ts))
SELECT count(*) AS customers_with_2nd_order,
       round((percentile_cont(0.25) WITHIN GROUP (ORDER BY d))::numeric, 1) AS p25_days,
       round((percentile_cont(0.50) WITHIN GROUP (ORDER BY d))::numeric, 1) AS median_days,
       round((percentile_cont(0.75) WITHIN GROUP (ORDER BY d))::numeric, 1) AS p75_days
FROM (SELECT EXTRACT(epoch FROM order_ts - prev_ts) / 86400.0 AS d FROM seq WHERE order_no = 2) x;
