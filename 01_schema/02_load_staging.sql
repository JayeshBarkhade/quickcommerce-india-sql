-- Phase 1b: bulk load with \copy (client-side COPY, no server file access needed).
-- Run from the project root so the relative data/ paths resolve.
\copy staging.cities FROM 'data/cities.csv' WITH (FORMAT csv, HEADER true)
\copy staging.stores FROM 'data/stores.csv' WITH (FORMAT csv, HEADER true)
\copy staging.customers FROM 'data/customers.csv' WITH (FORMAT csv, HEADER true)
\copy staging.products FROM 'data/products.csv' WITH (FORMAT csv, HEADER true)
\copy staging.orders FROM 'data/orders.csv' WITH (FORMAT csv, HEADER true)
\copy staging.order_items FROM 'data/order_items.csv' WITH (FORMAT csv, HEADER true)
\copy staging.order_feedback FROM 'data/order_feedback.csv' WITH (FORMAT csv, HEADER true)
\copy staging.weather_daily FROM 'data/weather_daily.csv' WITH (FORMAT csv, HEADER true)
