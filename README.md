# postgres-migrations

A [Claude Code](https://claude.com/claude-code) skill for zero-downtime PostgreSQL migration
safety on shared production infrastructure: real lock levels per operation (not intuition),
expand/contract instead of rename/drop in one step, `CREATE INDEX CONCURRENTLY` done right
(including why it can't share a transaction with anything else), batched backfills, and the
backup/restore drill `runway`'s G9 asks for.

## Install

```
/plugin marketplace add MubiZero/postgres-migrations
/plugin install postgres-migrations@postgres-migrations
```

## What it does

See [skills/postgres-migrations/SKILL.md](skills/postgres-migrations/SKILL.md), and
`references/lock-levels.md` / `references/expand-contract.md` for the detail.

## License

[MIT License](LICENSE) · Copyright (c) 2026 MubiZero
