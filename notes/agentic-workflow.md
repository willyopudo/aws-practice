# Agentic workflow — why it's built this way

## The loop
spec → `spec-branch.sh` (fresh branch off `origin/main`) → implement → `quality-gate.sh`
→ fix → … → PASS → notify → **you approve** → commit → push → PR → CI runs the same gate.

## Where control lives (and why it isn't just in the prompt)
Instructions in a prompt are advice. Hooks and permission rules are enforced by the harness,
so they hold even when the model drifts.

| Concern | Enforced by |
|---|---|
| Approval before shipping | `permissions.ask` on `git commit`, `git push`, `gh pr create`. Headless mode denies "ask" outright. |
| One branch per spec | `spec-branch.sh` cuts the branch. `bash-guard.sh` blocks commits from `main` or from a different branch. |
| No hook bypass, force-push or push to main | `bash-guard.sh` and `permissions.deny` |
| No org accounts, no real infra in spec runs | `bash-guard.sh` (aws calls with an org profile; `terraform apply` while a run is active) |
| Can't quit with a red gate | `stop-gate.sh` (Stop hook), capped by `max_iterations` and loop-safe |
| Lint errors caught at once | `fast-lint.sh` (PostToolUse, on the edited file only) |

## Token strategy
- **Summaries, not logs.** `quality-gate.sh` prints one line plus ≤40 lines of the first failure.
  Full logs sit in `.agent/logs/` and are read only on demand.
- **Fail fast.** The gate stops at the first failing stage. Coverage numbers mean nothing while tests fail.
- **Per-file lint in hooks**, so problems don't pile up into a large gate failure later.
- **Subagents with smaller models.** `test-writer` (Sonnet) writes tests in its own context.
  `gate-triage` (Haiku) reads logs and returns ≤15 lines. Only conclusions reach the main context.
- **State on disk** (`.agent/runs/<id>.md`, `.agent/iterations`), so a resumed run doesn't re-derive progress.
- **Caps.** `MAX_THINKING_TOKENS` and `BASH_MAX_OUTPUT_LENGTH` are set in `.claude/settings.json`.
  The spec sets `max_iterations`, and headless runs also get `max_turns` and `max_budget_usd`.

## Coverage on shell scripts
SonarCloud has no shell analyzer, so the 80% gate is enforced locally by kcov (in Docker, so
macOS and CI match). `scripts/coverage-check.sh` counts in-scope scripts that never ran as
0%. Without that, kcov's "only report what ran" behaviour would inflate the number.
Deliberate exclusions, each with its reason, are in `tests/coverage-exclude.txt`.

Sonar's job here is Terraform/IaC rules, secrets, Dockerfile and GitHub Actions checks.

## Later
- Parallel specs: `git worktree add ../aws-practice-<id> -b spec/<id>-…`, one Claude session per worktree.
- Tests for the workflow tooling itself (it's in the coverage-exclude list for now).
