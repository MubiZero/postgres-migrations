-- Safe zero-downtime migration example (outside transaction wrapper for CONCURRENTLY, with lock_timeout and NOT VALID -> VALIDATE -> SET NOT NULL)
SET lock_timeout = '3s';
SET statement_timeout = '15s';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_user_id ON orders (user_id);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS source text DEFAULT 'web';

ALTER TABLE orders ADD CONSTRAINT chk_orders_phone_nn CHECK (customer_phone IS NOT NULL) NOT VALID;
ALTER TABLE orders VALIDATE CONSTRAINT chk_orders_phone_nn;
ALTER TABLE orders ALTER COLUMN customer_phone SET NOT NULL;
ALTER TABLE orders DROP CONSTRAINT chk_orders_phone_nn;
