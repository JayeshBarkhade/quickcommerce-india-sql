-- Phase 4a: MATERIALIZED VIEW for RFM (same logic and tie-breakers as Q4).
-- Why: RFM scoring needs a full scan plus two window sorts over every customer. Dashboards and the lookup functions
-- should read a precomputed table instead of recomputing it on every call.
-- Trade-off: the data is a snapshot; refresh after each load (REFRESH ... CONCURRENTLY keeps it readable meanwhile).
DROP MATERIALIZED VIEW IF EXISTS qc.mv_rfm CASCADE;
CREATE MATERIALIZED VIEW qc.mv_rfm AS
WITH snapshot AS (
  SELECT max(order_ts)::date + 1 AS snap FROM qc.v_delivered_orders),
cust AS (
  SELECT customer_id, (SELECT snap FROM snapshot) - max(order_ts)::date AS recency_days, count(*) AS frequency,
         sum(amount_paid) AS monetary, min(order_ts)::date AS first_order, max(order_ts)::date AS last_order
  FROM qc.v_delivered_orders GROUP BY 1),
scored AS (
  SELECT *, 6 - NTILE(5) OVER (ORDER BY recency_days, customer_id) AS r_score,
         CASE WHEN frequency >= 10 THEN 3 WHEN frequency >= 3 THEN 2 ELSE 1 END AS f_score,
         NTILE(5) OVER (ORDER BY monetary, customer_id) AS m_score
  FROM cust)
SELECT customer_id, recency_days, frequency, monetary, first_order, last_order, r_score, f_score, m_score,
       CASE
         WHEN f_score = 3 AND r_score >= 4  THEN '1 Champions (10+ orders, recent)'
         WHEN f_score >= 2 AND r_score >= 3 THEN '2 Loyal regulars'
         WHEN f_score >= 2                  THEN '3 At-risk regulars (going quiet)'
         WHEN r_score >= 4                  THEN '4 New or occasional, recent'
         ELSE                                    '5 Lapsed light users' END AS segment
FROM scored;
-- A UNIQUE index is required for REFRESH ... CONCURRENTLY and makes single-customer lookups instant.
CREATE UNIQUE INDEX mv_rfm_customer_uidx ON qc.mv_rfm (customer_id);
CREATE INDEX mv_rfm_segment_idx ON qc.mv_rfm (segment);
REFRESH MATERIALIZED VIEW CONCURRENTLY qc.mv_rfm;
ANALYZE qc.mv_rfm;
