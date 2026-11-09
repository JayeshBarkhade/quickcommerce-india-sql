-- Phase 4d: secondary indexes. Each one exists because a measured query needed it (see results/explain_before_after.md).
-- Primary keys already index: orders(order_id), order_items(order_id, line_no), order_feedback(order_id).
-- Deliberately NOT created: indexes on columns no query filters or joins on (every index slows writes and costs disk).

-- "Everything this customer ever ordered, in time order": the most common app query, no sort needed.
CREATE INDEX IF NOT EXISTS idx_orders_customer_ts ON qc.orders (customer_id, order_ts);

-- Store dashboards ("how busy was dark store X yesterday?") filter by store and time window.
CREATE INDEX IF NOT EXISTS idx_orders_store_ts ON qc.orders (store_id, order_ts);

-- PARTIAL index: nearly every report filters on delivered orders and a date range. Indexing only those rows keeps
-- the index smaller and faster than a full order_ts index.
CREATE INDEX IF NOT EXISTS idx_orders_delivered_ts ON qc.orders (order_ts) WHERE status = 'delivered';

-- Product-level analysis (top products, a product page's sales) joins order_items on product_id.
CREATE INDEX IF NOT EXISTS idx_items_product ON qc.order_items (product_id);

ANALYZE;
