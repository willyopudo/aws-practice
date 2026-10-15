---
id: NNN-short-name            # becomes the branch: spec/NNN-short-name-<timestamp>
coverage_min: 80              # % line coverage of in-scope shell scripts
sonar: true                   # false to skip the SonarCloud stage locally (CI still runs it)
max_iterations: 5             # quality-gate runs before the agent must stop and report
max_turns: 60                 # headless only (scripts/agent-run.sh)
max_budget_usd: 3             # headless only — hard spend cap for the run
model: sonnet                 # headless only — sonnet | opus | haiku
---

# <Title>

## Objective
One or two sentences: what should be true when this is done, and why.

## Acceptance criteria
Each item must be checkable — by a test, a command, or reading the diff.
- [ ] ...
- [ ] Quality gate passes (`scripts/quality-gate.sh`).

## Scope
Paths the agent may change (tests/ is always allowed).
- `path/to/file.sh`

## Out of scope
- No real AWS calls or resources. Terraform changes use `terraform test` with `mock_provider`.

## Notes
Context, constraints, links. Optional.
