# Contributing

## Commit conventions

This repo uses **Conventional Commits** strictly. Release-please parses them to generate version bumps.

- `feat:` — minor bump
- `fix:` — patch bump
- `feat!:` or `BREAKING CHANGE` — major bump
- `chore:`, `docs:`, `ci:`, `refactor:` — no version bump

Always use `feat:` or `fix:` for changes that should trigger a release.

## Adding resources

All content lives in `plugins/<plugin-name>/src/`. The `claude/`, `opencode/`, and `openclaw/` directories contain symlinks. See `plugins/acme-engineering/claude/AGENTS.md` for the change propagation table.

## Testing

After modifying hooks or scripts:

```bash
bash plugins/acme-engineering/tests/run-all.sh
```

## Branch workflow

```bash
git fetch origin && git checkout main && git pull origin main
git checkout -b feat/your-feature
```

Always create PRs — never push to main directly.
