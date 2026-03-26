---
description: Detect the project test framework and run the suite
---

Detect the test framework used by the current project and run it.

## Detection order

1. Check `package.json` for test script → `npm test`
2. Check for `go.mod` → `go test ./...`
3. Check for `pyproject.toml` with pytest → `pytest`
4. Check for `Makefile` with test target → `make test`

If no test framework is detected, tell the user.

After running, report the results: total tests, passed, failed, skipped. If any tests fail, show the failure output.
