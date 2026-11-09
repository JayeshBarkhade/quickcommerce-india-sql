-- Q2. Demand and delivery speed by hour of day: when do orders peak, and does speed suffer at the peak?
-- Skills: EXTRACT, GROUP BY, RANK() window, share-of-total window, FILTER-free boolean average.
SELECT EXTRACT(hour FROM order_ts)::int AS hour, count(*) AS orders,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct_of_orders,
       RANK() OVER (ORDER BY count(*) DESC) AS demand_rank,
       round(avg(delivery_minutes)::numeric, 1) AS avg_delivery_min,
       round(100.0 * avg(sla_met::int), 1) AS sla_met_pct
FROM qc.v_delivered_orders
GROUP BY 1 ORDER BY 1;
