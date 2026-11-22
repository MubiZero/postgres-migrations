---
name: postgres-migrations
description: >-
  Zero-downtime PostgreSQL migration review & linter (check_migration.sh): statement lock levels, expand/contract,
  CREATE INDEX CONCURRENTLY, lock_timeout, batched backfill, and G9 backup/restore verification. Use before any
  production migration and on: "миграция не положит прод?", "добавь колонку/индекс безопасно", "ревью миграции",
  is this migration safe, zero-downtime migration.
---

# postgres-migrations: Zero-Downtime Production Migrations

Production migrations fail not from syntax errors, but from unmeasured table locks or assuming old and new application code never run simultaneously. On shared infrastructure (e.g., Coolify hosting multiple Go services), a lock stall takes down more than one product.

## Workflow

1. **Run the Static Linter & Classify Locks.** Run `bash <skill>/scripts/check_migration.sh <file.sql>` and verify every statement against [references/lock-levels.md](references/lock-levels.md).
2. **Use Expand/Contract for Renames, Type Changes, and Drops** — see [references/expand-contract.md](references/expand-contract.md). Old app instances still query the old schema during rolling deploys.
3. **Indexes: Always `CREATE INDEX CONCURRENTLY`** on live tables.
   - `CONCURRENTLY` cannot run inside a transaction block (`BEGIN ... COMMIT`); disable the migration runner's transaction wrapper for that file.
   - If a `CONCURRENTLY` build fails mid-way, it leaves an `INVALID` index—drop it with `DROP INDEX CONCURRENTLY` and rebuild.
4. **Guard DDL with `lock_timeout` and `statement_timeout`.** Prefix catalog-only `ALTER TABLE` statements with `SET LOCAL lock_timeout = '3s'; SET LOCAL statement_timeout = '15s';`. Failing fast and retrying is far safer than queueing `ACCESS EXCLUSIVE` behind a slow query and freezing all table traffic.
5. **Backfill in Batches.** Never run an unbounded `UPDATE` across millions of rows in one transaction; update 1,000–10,000 rows per batch with a brief pause to avoid long locks and WAL bloat.
6. **Test on Production-Scale Data & Verify Backup (`runway` G9).** Before any destructive/data-mutating migration, confirm a fresh backup exists and **restore from it was actually tested** (`pg_dump`/`pg_restore` or volume snapshot).

## Pre-Production Checklist (Report in Russian)
- [ ] Exact lock level named for every SQL statement (`check_migration.sh` clean).
- [ ] Renames / type changes / drops follow expand/contract across deploy waves.
- [ ] Indexes use `CONCURRENTLY` outside a transaction block.
- [ ] `lock_timeout` set on all `ALTER TABLE` statements.
- [ ] Data backfills run in bounded batches.
- [ ] Fresh backup verified for restorability; production execution awaits explicit owner command (R5).

## Files
- `scripts/check_migration.sh` & `scripts/selftest.sh` — static SQL linter and automated tests on `evals/{bad_locking.sql,good_safe.sql}`.
- `references/lock-levels.md` — lock duration and safety per PostgreSQL DDL operation.
- `references/expand-contract.md` — step-by-step zero-downtime column rename, type change, and drop patterns.
