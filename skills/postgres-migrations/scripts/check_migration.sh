#!/usr/bin/env bash
# check_migration.sh — static zero-downtime safety checker for PostgreSQL .sql migration files.
# Catches the 5 production-locking mistakes from references/lock-levels.md:
#   1. CREATE [UNIQUE] INDEX without CONCURRENTLY
#   2. CREATE/DROP INDEX CONCURRENTLY wrapped inside BEGIN / COMMIT transaction
#   3. ADD COLUMN ... DEFAULT <volatile> (now(), clock_timestamp(), random(), gen_random_uuid(), uuid_generate_v4())
#   4. ALTER COLUMN ... SET NOT NULL without prior VALIDATE CONSTRAINT in the file (or explicit -- safe: <reason>)
#   5. ALTER TABLE without SET [LOCAL] lock_timeout
#
# Usage: bash check_migration.sh <migration.sql> [...]
# Exits 1 if any [BLOCKER] is found, 0 otherwise.
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: bash check_migration.sh <migration.sql> [...]" >&2; exit 2; }

python3 - "$@" <<'PY'
import re, sys

RE_COMMENT = re.compile(r"--[^\n]*")
RE_CREATE_INDEX = re.compile(r"\bCREATE\s+(?:UNIQUE\s+)?INDEX\b(?!\s+CONCURRENTLY\b)", re.IGNORECASE)
RE_CONCURRENTLY = re.compile(r"\b(?:CREATE|DROP)\s+(?:UNIQUE\s+)?INDEX\s+CONCURRENTLY\b", re.IGNORECASE)
RE_BEGIN = re.compile(r"\bBEGIN\b", re.IGNORECASE)
RE_VOLATILE_DEFAULT = re.compile(
    r"\bADD\s+COLUMN\b[^;]*\bDEFAULT\s+(?:now|clock_timestamp|current_timestamp|random|gen_random_uuid|uuid_generate_v4)\s*\(",
    re.IGNORECASE | re.DOTALL,
)
RE_SET_NOT_NULL = re.compile(r"\bALTER\s+COLUMN\b[^;]*\bSET\s+NOT\s+NULL\b", re.IGNORECASE)
RE_VALIDATE = re.compile(r"\bVALIDATE\s+CONSTRAINT\b", re.IGNORECASE)
RE_ALTER_TABLE = re.compile(r"\bALTER\s+TABLE\b", re.IGNORECASE)
RE_LOCK_TIMEOUT = re.compile(r"\block_timeout\b", re.IGNORECASE)

failed = 0
for path in sys.argv[1:]:
    raw = open(path, encoding="utf-8").read()
    has_safe_override = "-- safe-not-null" in raw.lower()
    sql = RE_COMMENT.sub("", raw)
    issues = []

    for m in RE_CREATE_INDEX.finditer(sql):
        issues.append(("BLOCKER", "CREATE INDEX without CONCURRENTLY locks writes on the table"))

    if RE_CONCURRENTLY.search(sql) and RE_BEGIN.search(sql):
        issues.append(("BLOCKER", "INDEX CONCURRENTLY cannot run inside a BEGIN/COMMIT transaction block"))

    if RE_VOLATILE_DEFAULT.search(sql):
        issues.append(("BLOCKER", "ADD COLUMN with volatile DEFAULT (now/gen_random_uuid/random) rewrites the entire table under ACCESS EXCLUSIVE"))

    if RE_SET_NOT_NULL.search(sql) and not (RE_VALIDATE.search(sql) or has_safe_override):
        issues.append(("BLOCKER", "Direct ALTER COLUMN SET NOT NULL scans the whole table under ACCESS EXCLUSIVE; use ADD CONSTRAINT CHECK NOT VALID + VALIDATE CONSTRAINT first"))

    if RE_ALTER_TABLE.search(sql) and not RE_LOCK_TIMEOUT.search(sql):
        issues.append(("BLOCKER", "ALTER TABLE without SET lock_timeout risks queueing behind a long query and blocking all traffic"))

    if issues:
        for sev, msg in issues:
            print(f"{path}: [{sev}] {msg}")
            if sev == "BLOCKER":
                failed += 1
    else:
        print(f"{path}: OK (zero-downtime checks passed)")

sys.exit(1 if failed else 0)
PY
