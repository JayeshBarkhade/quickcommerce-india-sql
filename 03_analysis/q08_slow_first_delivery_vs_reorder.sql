-- Q8. Does a SLOW FIRST DELIVERY reduce the chance a customer orders again within 30 days?
-- Skills: DISTINCT ON, EXISTS rewritten as a LEFT JOIN, FILTER, CASE bucketing, full-observation-window cohort design.
-- Design: first delivered order per customer; only customers with 30 observable days; rows with unusable delivery
-- times (dq_flag) are excluded. Shows association, not proof of cause (slow areas also differ in other ways).
-- Performance: the CTE is NOT MATERIALIZED so the planner keeps real table statistics (see README, Lessons learned).
WITH co AS NOT MATERIALIZED (
  SELECT customer_id, order_ts, delivery_minutes, dq_flag FROM qc.v_delivered_orders),
bounds AS (
  SELECT max(order_ts) AS max_ts FROM co),
first_orders AS (
  SELECT DISTINCT ON (customer_id) customer_id, order_ts, delivery_minutes, dq_flag
  FROM co ORDER BY customer_id, order_ts),
eligible AS (
  SELECT f.* FROM first_orders f CROSS JOIN bounds b
  WHERE f.order_ts <= b.max_ts - interval '30 days' AND f.dq_flag IS NULL),
repeaters AS (
  SELECT DISTINCT e.customer_id
  FROM eligible e JOIN co o ON o.customer_id = e.customer_id
                           AND o.order_ts > e.order_ts AND o.order_ts <= e.order_ts + interval '30 days'),
flagged AS (
  SELECT e.*, (r.customer_id IS NOT NULL) AS reordered_30d
  FROM eligible e LEFT JOIN repeaters r USING (customer_id))
SELECT CASE WHEN delivery_minutes <= 10 THEN '1  up to 10 min' WHEN delivery_minutes <= 15 THEN '2  11-15 min'
            WHEN delivery_minutes <= 20 THEN '3  16-20 min' ELSE '4  over 20 min' END AS first_order_delivery_time,
       count(*) AS customers, count(*) FILTER (WHERE reordered_30d) AS reordered,
       round(100.0 * count(*) FILTER (WHERE reordered_30d) / count(*), 1) AS reorder_30d_pct
FROM flagged GROUP BY 1 ORDER BY 1;
