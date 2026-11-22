#!/usr/bin/env bash
# Selftest for postgres-migrations: manifests, frontmatter, links, check_migration.sh on bad & good SQL fixtures.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
skill="$(cd "$here/.." && pwd)"
root="$(cd "$skill/../.." && pwd)"
fail=0
bad() { echo "FAIL  $*"; fail=1; }
ok()  { echo "ok    $*"; }

v1=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$root/plugin.json")
v2=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$root/.claude-plugin/plugin.json")
v3=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["plugins"][0]["version"])' "$root/.claude-plugin/marketplace.json")
[ "$v1" = "$v2" ] && [ "$v1" = "$v3" ] && ok "manifest versions agree ($v1)" || bad "manifest versions differ ($v1 / $v2 / $v3)"

bash "$here/check_migration.sh" "$skill/evals/good_safe.sql" >/dev/null && ok "good_safe.sql passes check_migration.sh" || bad "good_safe.sql failed"
if bash "$here/check_migration.sh" "$skill/evals/bad_locking.sql" >/dev/null 2>&1; then
  bad "bad_locking.sql was not caught by check_migration.sh"
else
  count=$(bash "$here/check_migration.sh" "$skill/evals/bad_locking.sql" 2>&1 | grep -c '\[BLOCKER\]' || true)
  [ "$count" -eq 5 ] && ok "bad_locking.sql caught all 5 locking blockers" || bad "bad_locking.sql caught $count blockers (expected 5)"
fi

[ "$fail" = 0 ] && echo "ALL OK" || exit 1
