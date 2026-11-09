-- Q11. Top 3 products by revenue inside each of the 6 biggest categories.
-- Skills: CROSS JOIN LATERAL (a per-row "top-N" subquery), LIMIT inside a subquery, joins to a lookup table.
-- LATERAL lets the inner query reference the outer row (c.category_id), which a plain join cannot.
WITH big_cats AS (
  SELECT p.category_id, sum(i.quantity * i.unit_price) AS revenue
  FROM qc.order_items i JOIN qc.products p USING (product_id) JOIN qc.orders o USING (order_id)
  WHERE o.status = 'delivered' GROUP BY 1 ORDER BY 2 DESC LIMIT 6)
SELECT pc.category_name AS category, row_number() OVER (PARTITION BY c.category_id ORDER BY top.revenue DESC) AS rank_in_category,
       top.product_name, top.units, round(top.revenue, 0) AS revenue_rs
FROM big_cats c
JOIN qc.product_categories pc USING (category_id)
CROSS JOIN LATERAL (
  SELECT p.product_name, sum(i.quantity) AS units, sum(i.quantity * i.unit_price) AS revenue
  FROM qc.order_items i JOIN qc.products p USING (product_id) JOIN qc.orders o USING (order_id)
  WHERE p.category_id = c.category_id AND o.status = 'delivered'
  GROUP BY p.product_id, p.product_name ORDER BY revenue DESC LIMIT 3) top
ORDER BY c.revenue DESC, rank_in_category;
