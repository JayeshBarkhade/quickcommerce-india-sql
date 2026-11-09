-- Q4. RFM segmentation (Recency, Frequency, Monetary) and the revenue each segment holds.
-- Skills: NTILE(), CASE, scalar subquery, share-of-total windows.
-- Determinism: recency is whole days, so thousands of customers tie. Every NTILE ends with customer_id as a
-- tie-breaker; without it two query plans can bucket tied customers differently.
-- Frequency uses fixed CASE bands (1-2, 3-9, 10+ orders) because quick-commerce order counts are heavily skewed.
WITH snapshot AS (
  SELECT max(order_ts)::date + 1 AS snap FROM qc.v_delivered_orders),
cust AS (
  SELECT customer_id, (SELECT snap FROM snapshot) - max(order_ts)::date AS recency_days,
         count(*) AS frequency, sum(amount_paid) AS monetary
  FROM qc.v_delivered_orders GROUP BY 1),
scored AS (
  SELECT *, 6 - NTILE(5) OVER (ORDER BY recency_days, customer_id) AS r_score,      -- 5 = ordered most recently
         CASE WHEN frequency >= 10 THEN 3 WHEN frequency >= 3 THEN 2 ELSE 1 END AS f_score,
         NTILE(5) OVER (ORDER BY monetary, customer_id) AS m_score
  FROM cust),
labelled AS (
  SELECT *, CASE
      WHEN f_score = 3 AND r_score >= 4  THEN '1 Champions (10+ orders, recent)'
      WHEN f_score >= 2 AND r_score >= 3 THEN '2 Loyal regulars'
      WHEN f_score >= 2                  THEN '3 At-risk regulars (going quiet)'
      WHEN r_score >= 4                  THEN '4 New or occasional, recent'
      ELSE                                    '5 Lapsed light users' END AS segment
  FROM scored)
SELECT segment, count(*) AS customers, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct_customers,
       round(avg(frequency), 1) AS avg_orders, round(avg(monetary), 0) AS avg_spend_rs,
       round(100.0 * sum(monetary) / sum(sum(monetary)) OVER (), 1) AS pct_revenue
FROM labelled GROUP BY segment ORDER BY segment;
