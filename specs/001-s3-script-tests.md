---
id: 001-s3-script-tests
coverage_min: 80
sonar: true
max_iterations: 5
max_turns: 60
max_budget_usd: 3
model: sonnet
---

# Tests for the S3 lab scripts and repo helpers

## Objective
The S3 lab scripts and the repo helpers have no tests. Add bats tests, run against the
fake `aws` in `tests/helpers/`, so changes to them are safe. Also make `new-lab.sh`
portable. This is the proof-of-concept for the spec-run workflow.

## Acceptance criteria
- [ ] One `.bats` file per script in `labs/s3/bash-scripts/`, plus `scripts/whoami.sh` and `scripts/new-lab.sh`.
- [ ] Each test file covers the happy path, the usage error (wrong arg count) and an AWS failure.
- [ ] `create-bucket.sh` tests cover both the `us-east-1` branch and the `LocationConstraint` branch.
- [ ] `whoami.sh` tests cover the practice account (exit 0) and a non-practice account (exit 2).
- [ ] `scripts/new-lab.sh` works on both macOS (BSD sed) and Linux (GNU sed). Its test runs in the Linux coverage container and must pass there.
      `new-lab.sh` tests use a temporary copy of the repo layout and never write into the real `labs/`.
- [ ] Line coverage ≥ 80% (`make coverage`), with no new entries in `tests/coverage-exclude.txt`.
- [ ] Quality gate passes (`scripts/quality-gate.sh`).

## Scope
- `tests/`
- `scripts/new-lab.sh` (portability fix only)
- `labs/s3/bash-scripts/` (only if a script is untestable as written — explain in the PR)

## Out of scope
- No real AWS calls. No changes to `scripts/sweep.sh` or the workflow tooling.
