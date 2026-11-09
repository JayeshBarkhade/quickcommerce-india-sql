-- Q12. Which categories are bought together in one basket (support and LIFT)?
-- Skills: DISTINCT baskets, self-join with a < b to avoid mirrored duplicates, support and lift arithmetic.
-- Lift > 1 means the pair appears together more often than chance; this feeds "frequently bought together" shelves.
WITH basket AS (
  SELECT DISTINCT i.order_id, p.category_id
  FROM qc.order_items i JOIN qc.products p USING (product_id) JOIN qc.orders o USING (order_id)
  WHERE o.status = 'delivered'),
tot AS (SELECT count(DISTINCT order_id) AS n FROM basket),
cat_cnt AS (SELECT category_id, count(*) AS n FROM basket GROUP BY 1),
pairs AS (
  SELECT a.category_id AS a_cat, b.category_id AS b_cat, count(*) AS together
  FROM basket a JOIN basket b ON a.order_id = b.order_id AND a.category_id < b.category_id GROUP BY 1, 2)
SELECT ca.category_name AS category_a, cb.category_name AS category_b, p.together AS orders_together,
       round(100.0 * p.together / t.n, 2) AS support_pct,
       round((p.together::numeric / t.n) / ((x.n::numeric / t.n) * (y.n::numeric / t.n)), 2) AS lift
FROM pairs p CROSS JOIN tot t
JOIN cat_cnt x ON x.category_id = p.a_cat
JOIN cat_cnt y ON y.category_id = p.b_cat
JOIN qc.product_categories ca ON ca.category_id = p.a_cat
JOIN qc.product_categories cb ON cb.category_id = p.b_cat
WHERE p.together >= 500
ORDER BY lift DESC, orders_together DESC LIMIT 10;
