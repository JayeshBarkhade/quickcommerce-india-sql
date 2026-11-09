-- Phase 2c: POST-LOAD VALIDATION. Every check should show problems = 0 (row counts are informational).
SELECT 'row count: ' || t AS check_name, n AS problems FROM (
  SELECT 'cities' t, count(*) n FROM qc.cities UNION ALL SELECT 'dark_stores', count(*) FROM qc.dark_stores UNION ALL
  SELECT 'customers', count(*) FROM qc.customers UNION ALL SELECT 'products', count(*) FROM qc.products UNION ALL
  SELECT 'orders', count(*) FROM qc.orders UNION ALL SELECT 'order_items', count(*) FROM qc.order_items UNION ALL
  SELECT 'order_feedback', count(*) FROM qc.order_feedback UNION ALL SELECT 'weather_daily', count(*) FROM qc.weather_daily) c
UNION ALL SELECT 'orders without a customer (orphans)', count(*) FROM qc.orders o
  WHERE NOT EXISTS (SELECT 1 FROM qc.customers c WHERE c.customer_id = o.customer_id)
UNION ALL SELECT 'order lines without a product (orphans)', count(*) FROM qc.order_items i
  WHERE NOT EXISTS (SELECT 1 FROM qc.products p WHERE p.product_id = i.product_id)
UNION ALL SELECT 'orders without any order line', count(*) FROM qc.orders o
  WHERE NOT EXISTS (SELECT 1 FROM qc.order_items i WHERE i.order_id = o.order_id)
UNION ALL SELECT 'delivered_ts before order_ts', count(*) FROM qc.orders WHERE delivered_ts < order_ts
UNION ALL SELECT 'cancelled orders with a delivery time', count(*) FROM qc.orders WHERE status = 'cancelled' AND delivered_ts IS NOT NULL
UNION ALL SELECT 'rows repaired and flagged in orders (informational)', count(*) FROM qc.orders WHERE dq_flag IS NOT NULL
UNION ALL SELECT 'amount_paid <> lines + fees - discount (proves dedupe is right)', count(*) FROM (
  SELECT o.order_id FROM qc.orders o
  JOIN (SELECT order_id, sum(quantity * unit_price) v FROM qc.order_items GROUP BY 1) i USING (order_id)
  WHERE abs(i.v + o.delivery_fee + o.handling_fee - o.discount_amount - o.amount_paid) > 0.011) z;
