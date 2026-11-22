# PostgreSQL Lock Levels by Operation

`ALTER TABLE` almost always takes `ACCESS EXCLUSIVE`. The difference between safe and production-breaking is **how long** the lock is held: a sub-millisecond catalog update vs a full table rewrite/scan.

## Safe (Instant Catalog Update, Independent of Table Size)
- **`ADD COLUMN` with a constant default** (`DEFAULT 0`, `DEFAULT 'x'`, `DEFAULT false`) on PostgreSQL 11+: stored in `pg_attribute` metadata without rewriting existing rows.
- **`ADD COLUMN` nullable without default**: instant on all versions.
- **`DROP COLUMN`**: marks column dropped in catalog; space is reclaimed later by background `VACUUM`.
- **`ADD CONSTRAINT ... NOT VALID`** (`CHECK` or `FOREIGN KEY`): enforces on new rows immediately without scanning existing rows. Follow with `VALIDATE CONSTRAINT`, which takes only `SHARE UPDATE EXCLUSIVE` (allows concurrent reads and writes).
- **Rename column/table**: instant catalog update, **but breaks running code**—must use expand/contract (`expand-contract.md`).

## Dangerous (Holds `ACCESS EXCLUSIVE` Across All Rows)
- **`ADD COLUMN` with a volatile default** (`DEFAULT now()`, `DEFAULT random()`, `DEFAULT gen_random_uuid()`): rewrites the entire table and rebuilds indexes on **every** PostgreSQL version. *Fix:* add nullable column → backfill in batches → `ALTER COLUMN SET DEFAULT` (instant) → add `NOT NULL` via `CHECK NOT VALID` + `VALIDATE`.
- **`ALTER COLUMN ... TYPE`** (when binary representation changes, e.g., `varchar → int`): full table rewrite.
- **`CREATE INDEX` without `CONCURRENTLY`**: takes `SHARE` lock, blocking all `INSERT`/`UPDATE`/`DELETE` until built. Always use `CREATE INDEX CONCURRENTLY` outside a transaction block.
- **Direct `ALTER COLUMN ... SET NOT NULL` without a prior validated CHECK**: scans the entire table under `ACCESS EXCLUSIVE`.
  *Zero-downtime path on PostgreSQL 12+:*
  1. `ALTER TABLE t ADD CONSTRAINT chk_col_nn CHECK (col IS NOT NULL) NOT VALID;`
  2. `ALTER TABLE t VALIDATE CONSTRAINT chk_col_nn;` (`SHARE UPDATE EXCLUSIVE`, non-blocking)
  3. `ALTER TABLE t ALTER COLUMN col SET NOT NULL;` (on PG 12+, sees the valid `CHECK` constraint and finishes **instantly without a table scan**)
  4. `ALTER TABLE t DROP CONSTRAINT chk_col_nn;`
