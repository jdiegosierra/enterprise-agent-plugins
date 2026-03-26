---
description: Detect the project linter and run autofix
---

Detect the linter used by the current project and run it with autofix enabled.

## Detection order

1. Check `package.json` for lint scripts → `npm run lint -- --fix` or `npx eslint --fix .`
2. Check for `.golangci.yml` → `golangci-lint run --fix`
3. Check for `pyproject.toml` with ruff → `ruff check --fix .`
4. Check for `.flake8` or `setup.cfg` with flake8 → `autopep8 --in-place --recursive .`

If no linter is detected, tell the user and suggest setting one up.

After running, report which files were modified and whether any issues remain unfixed.
