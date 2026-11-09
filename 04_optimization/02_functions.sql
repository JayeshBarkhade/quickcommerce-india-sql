-- Phase 4b: reusable SQL functions on top of the materialized view.
CREATE OR REPLACE FUNCTION qc.get_customer_segment(p_customer_id integer)
RETURNS text LANGUAGE sql STABLE AS
$$ SELECT segment FROM qc.mv_rfm WHERE customer_id = p_customer_id $$;

CREATE OR REPLACE FUNCTION qc.customer_profile(p_customer_id integer)
RETURNS TABLE (orders bigint, total_spend_rs numeric, first_order date, last_order date, avg_rating numeric, segment text)
LANGUAGE sql STABLE AS
$$ SELECT m.frequency, round(m.monetary, 0), m.first_order, m.last_order,
          (SELECT round(avg(f.rating), 2) FROM qc.order_feedback f JOIN qc.orders o USING (order_id)
           WHERE o.customer_id = m.customer_id),
          m.segment
   FROM qc.mv_rfm m WHERE m.customer_id = p_customer_id $$;

\echo '-- customer_profile() for the top spender'
SELECT * FROM qc.customer_profile((SELECT customer_id FROM qc.mv_rfm ORDER BY monetary DESC, customer_id LIMIT 1));
\echo '-- get_customer_segment() for the same customer'
SELECT qc.get_customer_segment((SELECT customer_id FROM qc.mv_rfm ORDER BY monetary DESC, customer_id LIMIT 1)) AS segment;
\echo '-- sanity: segment sizes from the materialised view (must match Q4)'
SELECT segment, count(*) AS customers FROM qc.mv_rfm GROUP BY 1 ORDER BY 1;
