-- Q5. Top 3 customers by spend in each of the 5 highest-revenue cities.
-- Skills: DENSE_RANK() OVER (PARTITION BY ...), subquery in WHERE, joins to a lookup table.
WITH spend AS (
  SELECT c.city_id, d.customer_id, count(*) AS orders, sum(d.amount_paid) AS spend
  FROM qc.v_delivered_orders d JOIN qc.customers c USING (customer_id) GROUP BY 1, 2),
top_cities AS (
  SELECT city_id FROM spend GROUP BY city_id ORDER BY sum(spend) DESC LIMIT 5),
ranked AS (
  SELECT *, DENSE_RANK() OVER (PARTITION BY city_id ORDER BY spend DESC) AS rnk
  FROM spend WHERE city_id IN (SELECT city_id FROM top_cities))
SELECT ci.city_name, r.rnk AS rank_in_city, r.customer_id, r.orders, round(r.spend, 0) AS spend_rs
FROM ranked r JOIN qc.cities ci USING (city_id)
WHERE r.rnk <= 3 ORDER BY ci.city_name, r.rnk;
