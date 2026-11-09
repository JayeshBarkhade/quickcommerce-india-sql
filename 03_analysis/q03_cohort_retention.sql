-- Q3. Cohort retention: of customers whose FIRST order was in month X, what % ordered again in month X+n?
-- Skills: CTEs, age(), FILTER aggregates (pivot), right-censoring guard (months not yet observed stay blank).
WITH co AS NOT MATERIALIZED (
  SELECT customer_id, order_ts FROM qc.v_delivered_orders),
bounds AS (
  SELECT date_trunc('month', max(order_ts))::date AS last_month FROM co),
first_order AS (
  SELECT customer_id, date_trunc('month', min(order_ts))::date AS cohort_month FROM co GROUP BY 1),
activity AS (
  SELECT DISTINCT f.cohort_month, f.customer_id,
         (EXTRACT(year FROM age(date_trunc('month', c.order_ts), f.cohort_month)) * 12
        + EXTRACT(month FROM age(date_trunc('month', c.order_ts), f.cohort_month)))::int AS month_index
  FROM co c JOIN first_order f USING (customer_id)),
cohort_size AS (
  SELECT cohort_month, count(*) AS n FROM first_order GROUP BY 1)
SELECT s.cohort_month, s.n AS cohort_size,
  CASE WHEN s.cohort_month + interval '1 month' <= b.last_month THEN round(100.0 * count(*) FILTER (WHERE a.month_index = 1) / s.n, 1) END AS m1_pct,
  CASE WHEN s.cohort_month + interval '2 month' <= b.last_month THEN round(100.0 * count(*) FILTER (WHERE a.month_index = 2) / s.n, 1) END AS m2_pct,
  CASE WHEN s.cohort_month + interval '3 month' <= b.last_month THEN round(100.0 * count(*) FILTER (WHERE a.month_index = 3) / s.n, 1) END AS m3_pct,
  CASE WHEN s.cohort_month + interval '4 month' <= b.last_month THEN round(100.0 * count(*) FILTER (WHERE a.month_index = 4) / s.n, 1) END AS m4_pct,
  CASE WHEN s.cohort_month + interval '5 month' <= b.last_month THEN round(100.0 * count(*) FILTER (WHERE a.month_index = 5) / s.n, 1) END AS m5_pct,
  CASE WHEN s.cohort_month + interval '6 month' <= b.last_month THEN round(100.0 * count(*) FILTER (WHERE a.month_index = 6) / s.n, 1) END AS m6_pct
FROM cohort_size s CROSS JOIN bounds b JOIN activity a USING (cohort_month)
GROUP BY s.cohort_month, s.n, b.last_month ORDER BY s.cohort_month;
