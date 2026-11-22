# Expand / Contract Pattern (Zero-Downtime Renames, Type Changes & Drops)

Code deploys and DB migrations are not atomic. During a rolling deploy, old app instances still query the old schema while new instances start.

## Renaming a Column (6 Waves)
1. **Expand:** Add the new column (nullable or constant default). Keep the old column.
2. **Dual-write:** Deploy code that writes to **both** columns and reads from the old one.
3. **Backfill:** Copy old → new for existing rows in bounded batches.
4. **Switch reads:** Deploy code that reads from the new column while still dual-writing (keeps rollback safe).
5. **Stop writing old:** Deploy code that reads and writes only the new column.
6. **Contract:** After the rollback window passes (days, not minutes), drop the old column.

## Changing a Column Type
Follow the same 6 waves, converting values on the fly during dual-write and batch backfill instead of running a table-rewriting `ALTER COLUMN ... TYPE`.

## Dropping a Column or Table
Before dropping:
1. Search (`rg`) across **all** services, workers, and cron jobs sharing the database—not just the main API.
2. Deploy code that removes all references first (including `SELECT *` ORM mappings that expect the column).
3. Wait out the rollback window before executing `DROP COLUMN` / `DROP TABLE`.
