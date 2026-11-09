-- Q7. Delivery speed by city: average vs median vs 90th percentile, and the share of orders inside the promised time.
-- Skills: PERCENTILE_CONT() WITHIN GROUP, ROLLUP for an overall row, HAVING, joins.
-- Why percentiles: the average hides the slow tail that customers actually remember.
SELECT COALESCE(ci.city_name, 'ALL CITIES') AS city, count(*) AS orders,
       round(avg(d.delivery_minutes)::numeric, 1) AS avg_min,
       round((percentile_cont(0.5) WITHIN GROUP (ORDER BY d.delivery_minutes))::numeric, 1) AS median_min,
       round((percentile_cont(0.9) WITHIN GROUP (ORDER BY d.delivery_minutes))::numeric, 1) AS p90_min,
       round(100.0 * avg(d.sla_met::int), 1) AS within_promise_pct
FROM qc.v_delivered_orders d JOIN qc.cities ci USING (city_id)
WHERE d.dq_flag IS NULL
GROUP BY ROLLUP (ci.city_name)
HAVING count(*) >= 500
ORDER BY (ci.city_name IS NULL), p90_min DESC;
