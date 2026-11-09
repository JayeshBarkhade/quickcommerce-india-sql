-- Q6. Which acquisition channels bring customers who NEVER order again?
-- Skills: DISTINCT ON, NOT EXISTS anti-join (kept in WHERE so it becomes a Hash Anti Join), LEFT JOIN count trick.
-- Only customers whose first order is at least 90 days before the end of the data are counted, so recent customers
-- who simply have not had time to return are not mislabelled as lost.
WITH co AS NOT MATERIALIZED (
  SELECT customer_id, order_ts FROM qc.v_delivered_orders),
bounds AS (
  SELECT max(order_ts) AS max_ts FROM co),
firsts AS (
  SELECT DISTINCT ON (customer_id) customer_id, order_ts FROM co ORDER BY customer_id, order_ts),
eligible AS (
  SELECT f.* FROM firsts f CROSS JOIN bounds b WHERE f.order_ts <= b.max_ts - interval '90 days'),
never_returned AS (
  SELECT e.customer_id FROM eligible e
  WHERE NOT EXISTS (SELECT 1 FROM co o WHERE o.customer_id = e.customer_id AND o.order_ts > e.order_ts))
SELECT c.acquisition_channel, count(*) AS eligible_customers, count(n.customer_id) AS never_reordered,
       round(100.0 * count(n.customer_id) / count(*), 1) AS never_reordered_pct
FROM eligible e
JOIN qc.customers c USING (customer_id)
LEFT JOIN never_returned n USING (customer_id)
GROUP BY c.acquisition_channel ORDER BY never_reordered_pct DESC;
