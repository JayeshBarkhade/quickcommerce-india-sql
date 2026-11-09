-- Phase 2b: staging -> clean typed tables (order matters because of foreign keys).
BEGIN;

-- (qc.cities and qc.city_alias are reference data, already seeded in 01_schema/03_schema.sql)

INSERT INTO qc.dark_stores
SELECT s.store_id::int, a.city_id, trim(s.locality), s.opened_date::date
FROM staging.stores s
LEFT JOIN qc.city_alias a ON a.alias = lower(trim(s.city));        -- an unknown spelling => NULL => load fails loudly

INSERT INTO qc.customers
SELECT c.customer_id::int, c.signup_date::date, a.city_id, lower(replace(trim(c.acquisition_channel), ' ', '_'))
FROM staging.customers c
LEFT JOIN qc.city_alias a ON a.alias = lower(trim(c.city));

INSERT INTO qc.product_categories
SELECT (row_number() OVER (ORDER BY category_name))::smallint, category_name
FROM (SELECT DISTINCT trim(category_name) AS category_name FROM staging.products) x;

INSERT INTO qc.products
SELECT p.product_id::int, pc.category_id, trim(p.product_name), p.mrp::numeric
FROM staging.products p JOIN qc.product_categories pc ON pc.category_name = trim(p.category_name);

-- Orders: normalise labels, repair impossible timestamps, and leave an audit trail in dq_flag.
INSERT INTO qc.orders
SELECT order_id, customer_id, store_id, order_ts, promised_minutes,
       CASE WHEN status = 'delivered' AND raw_delivered >= order_ts THEN raw_delivered END AS delivered_ts,
       status, payment_method, delivery_fee, handling_fee, discount_amount, amount_paid,
       CASE WHEN status = 'delivered' AND raw_delivered < order_ts  THEN 'delivered_before_order'
            WHEN status = 'delivered' AND raw_delivered IS NULL     THEN 'delivered_missing_date'
            WHEN status = 'cancelled' AND raw_delivered IS NOT NULL THEN 'cancelled_with_delivery_ts' END AS dq_flag
FROM (SELECT order_id::int AS order_id, customer_id::int AS customer_id, store_id::int AS store_id,
             order_ts::timestamp AS order_ts, promised_minutes::smallint AS promised_minutes,
             NULLIF(delivered_ts, '')::timestamp AS raw_delivered,
             CASE WHEN lower(trim(status)) = 'canceled' THEN 'cancelled' ELSE lower(trim(status)) END AS status,
             CASE regexp_replace(lower(trim(payment_method)), '\s+', '', 'g')
                  WHEN 'upi' THEN 'UPI' WHEN 'card' THEN 'CARD' WHEN 'creditcard' THEN 'CARD'
                  WHEN 'debitcard' THEN 'CARD' WHEN 'cod' THEN 'COD' WHEN 'cashondelivery' THEN 'COD'
                  WHEN 'wallet' THEN 'WALLET' WHEN 'netbanking' THEN 'NETBANKING' END AS payment_method,
             delivery_fee::numeric AS delivery_fee, handling_fee::numeric AS handling_fee,
             discount_amount::numeric AS discount_amount, amount_paid::numeric AS amount_paid
      FROM staging.orders) o;

-- Order lines: drop zero-quantity junk, keep one copy of any double-posted line.
INSERT INTO qc.order_items
SELECT order_id::int, line_no::smallint, product_id::int, quantity::smallint, unit_price::numeric
FROM (SELECT i.*, ROW_NUMBER() OVER (PARTITION BY order_id, line_no ORDER BY ctid) AS rn
      FROM staging.order_items i WHERE quantity::int > 0) x
WHERE rn = 1;

-- Feedback: drop impossible ratings first, then keep the latest remaining rating per order.
INSERT INTO qc.order_feedback
SELECT order_id::int, rating::smallint, NULLIF(trim(tag), ''), created_ts::timestamp
FROM (SELECT f.*, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY created_ts DESC) AS rn
      FROM staging.order_feedback f WHERE rating::int BETWEEN 1 AND 5) x
WHERE rn = 1;

INSERT INTO qc.weather_daily SELECT city_id::smallint, day::date, rainfall_mm::numeric FROM staging.weather_daily;

COMMIT;
ANALYZE;
