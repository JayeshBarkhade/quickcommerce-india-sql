# EXPLAIN ANALYZE: before vs after indexing

Median of 7 runs (after 1 warm-up run), all data cached in memory, PostgreSQL 16.15. Full plans are in `results/plans/`.

| Query | Before (ms) | After (ms) | Speed-up | Indexes used after |
|---|---:|---:|---:|---|
| Order history of one customer (orders + line counts) | 12.7 | 0.3 | 36.5x | idx_orders_customer_ts |
| Daily revenue for one week (date range on delivered orders) | 17.2 | 5.1 | 3.3x | idx_orders_delivered_ts |
| Units and revenue for ONE product (a product page) | 23.7 | 2.1 | 11.5x | idx_items_product |
| One dark store, one day (store dashboard) | 12.9 | 0.1 | 93.7x | idx_orders_store_ts |
| Q8: slow first delivery vs reorder (full analytical query) | 473.1 | 457.4 | 1.0x | idx_orders_customer_ts |
| Q11: top 3 products per category (LATERAL) | 1,632.5 | 1,622.9 | 1.0x | (none: planner kept seq scan) |

Indexes created: `idx_orders_customer_ts`, `idx_orders_store_ts`, `idx_orders_delivered_ts`, `idx_items_product`
