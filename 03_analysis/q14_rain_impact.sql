-- Q14. Monsoon effect: how much does rain slow deliveries and break the delivery promise?
-- Skills: joining operational data to an external daily weather table, CASE bucketing, PERCENTILE_CONT, boolean average.
-- Rain is looked up per city per calendar day (weather_daily), the way an analyst would join IMD rainfall data.
SELECT CASE WHEN w.rainfall_mm >= 10 THEN '3 Heavy rain (10 mm or more)'
            WHEN w.rainfall_mm >= 2  THEN '2 Light rain (2 to 10 mm)'
            ELSE '1 No or trace rain (under 2 mm)' END AS weather,
       count(*) AS orders,
       round(avg(d.delivery_minutes)::numeric, 1) AS avg_delivery_min,
       round((percentile_cont(0.9) WITHIN GROUP (ORDER BY d.delivery_minutes))::numeric, 1) AS p90_min,
       round(100.0 * avg(d.sla_met::int), 1) AS within_promise_pct
FROM qc.v_delivered_orders d
JOIN qc.weather_daily w ON w.city_id = d.city_id AND w.day = d.order_ts::date
WHERE d.dq_flag IS NULL
GROUP BY 1 ORDER BY 1;
