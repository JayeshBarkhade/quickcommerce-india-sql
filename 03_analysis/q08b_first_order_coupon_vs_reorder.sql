-- Q8b. Do customers acquired with a first-order coupon come back as often as those who paid full price?
-- Skills: same cohort design as Q8, CASE, FILTER, averages next to rates. Tells marketing whether discounts buy loyalty.
WITH co AS NOT MATERIALIZED (
  SELECT customer_id, order_ts, discount_amount, amount_paid, dq_flag FROM qc.v_delivered_orders),
bounds AS (
  SELECT max(order_ts) AS max_ts FROM co),
first_orders AS (
  SELECT DISTINCT ON (customer_id) customer_id, order_ts, discount_amount, amount_paid, dq_flag
  FROM co ORDER BY customer_id, order_ts),
eligible AS (
  SELECT f.* FROM first_orders f CROSS JOIN bounds b WHERE f.order_ts <= b.max_ts - interval '30 days' AND f.dq_flag IS NULL),
repeaters AS (
  SELECT DISTINCT e.customer_id
  FROM eligible e JOIN co o ON o.customer_id = e.customer_id
                           AND o.order_ts > e.order_ts AND o.order_ts <= e.order_ts + interval '30 days')
SELECT CASE WHEN e.discount_amount > 0 THEN 'Used a first-order coupon' ELSE 'Paid full price' END AS first_order,
       count(*) AS customers, round(avg(e.amount_paid), 0) AS avg_first_order_rs,
       round(100.0 * count(r.customer_id) / count(*), 1) AS reorder_30d_pct
FROM eligible e LEFT JOIN repeaters r USING (customer_id)
GROUP BY (e.discount_amount > 0) ORDER BY 1 DESC;
