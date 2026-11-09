-- Q15 (MBA angle). Break-even and profit of a win-back coupon aimed at "lapsed regulars":
-- customers with 3+ orders whose last order was 30+ days before the end of the data.
-- Skills: parameter CTE, scenario table with VALUES, break-even arithmetic.
-- !! The three parameters below are ASSUMPTIONS made up for illustration, not facts from the data.
--    Quick-commerce margins are thin, so the result is very sensitive to them; replace with real figures.
WITH params AS (
  SELECT 0.18::numeric AS contribution_margin,   -- assumed share of order value kept as profit
         50.00::numeric AS coupon_rs,             -- assumed coupon value, paid only if redeemed
         0.50::numeric AS contact_cost_rs),       -- assumed cost to message one customer (push/SMS/WhatsApp)
snapshot AS (SELECT max(order_ts)::date + 1 AS snap FROM qc.v_delivered_orders),
cust AS (
  SELECT customer_id, (SELECT snap FROM snapshot) - max(order_ts)::date AS recency_days, count(*) AS frequency,
         avg(amount_paid) AS aov
  FROM qc.v_delivered_orders GROUP BY 1),
target AS (SELECT count(*) AS n, avg(aov) AS aov FROM cust WHERE frequency >= 3 AND recency_days >= 30),
scen AS (SELECT * FROM (VALUES (0.03), (0.06), (0.10)) v(reactivation_rate))
SELECT t.n AS target_customers, round(t.aov, 0) AS avg_order_value_rs, s.reactivation_rate,
       round(t.n * s.reactivation_rate) AS expected_reactivated,
       round(t.n * p.contact_cost_rs, 0) AS messaging_cost_rs,
       round(t.n * s.reactivation_rate * p.coupon_rs, 0) AS coupon_cost_rs,
       round(t.n * s.reactivation_rate * t.aov * p.contribution_margin, 0) AS profit_before_costs_rs,
       round(t.n * s.reactivation_rate * (t.aov * p.contribution_margin - p.coupon_rs) - t.n * p.contact_cost_rs, 0) AS net_profit_rs,
       round(100 * p.contact_cost_rs / (t.aov * p.contribution_margin - p.coupon_rs), 2) AS break_even_rate_pct
FROM target t CROSS JOIN params p CROSS JOIN scen s ORDER BY s.reactivation_rate;
