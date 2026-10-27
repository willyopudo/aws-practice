---
name: spec-run
description: Implement a spec from specs/ end to end — own branch, iterate until the quality gate passes (tests, coverage, lint; SonarCloud runs in CI), notify, wait for approval, then commit, push and open a PR. Use when the user runs /spec-run or asks to implement a spec file.
argument-hint: specs/NNN-name.md
---

# Spec run: $ARGUMENTS

Follow these steps in order. Keep output terse: no narration between tool calls, no
re-reading files you already have, no pasting full logs.

## 1. Branch (always first)
Run `scripts/spec-branch.sh $ARGUMENTS`. If it fails, report the message and stop.
Every spec runs on its own fresh branch from `origin/main`. Never work on `main`.
In headless mode (`AGENT_HEADLESS=1`), `scripts/agent-run.sh` has already done this.
Check with `git branch --show-current` and skip if you're on `spec/<id>-*`.

## 2. Understand
Read the spec once. Note the frontmatter limits (`max_iterations`, `coverage_min`, `sonar`)
and the **Scope** list. Don't edit files outside Scope, except `tests/` and the spec's
own notes. Append a 3–6 line plan to `.agent/runs/<id>.md`.

## 3. Implement
- Where the work is testable, write tests first. Tests use bats plus the fake `aws` in
  `tests/helpers/`. Load it with `load helpers/common` and call `setup_aws_mock` in `setup`.
  Tests must **never** call real AWS.
- For broad test-writing, delegate to the `test-writer` subagent with the specific
  script and the uncovered lines. It reports back briefly.
- The PostToolUse hook lints each file you edit. Fix what it reports right away.

## 4. Gate loop
Run `scripts/quality-gate.sh`. It prints one summary line plus a short excerpt.
- **PASS**: go to step 5.
- **FAIL**: fix only what it reports, then re-run. Read `.agent/logs/<stage>.log` only if
  the excerpt isn't enough. If even that is unclear, ask the `gate-triage` subagent.
- **ITERATION LIMIT REACHED**: stop fixing. Go to step 6 and report the remaining failures.
- `sonar: SKIPPED` is expected: SonarCloud runs in CI on the PR. Use `make sonar-local` for a
  quick local check if needed.

## 5. Self-check
- Tick each acceptance criterion in the spec, with one line of evidence each.
- Run `git diff --stat`, then check that the diff contains no secrets, org account ids or
  real usernames (see CLAUDE.md).

## 6. Notify and report
Run `.claude/hooks/notify.sh "Spec <id>: gate <PASS|FAIL> — approval needed"`.
Then print this report (≤25 lines):
```
Spec <id> on <branch> — gate <PASS|FAIL> after <n> iteration(s)
<gate summary line>
Acceptance: ✓/✗ per item
Changes: <git diff --stat summary>
Proposed commit: <type>: <subject>
```

## 7. Approval
- **Headless** (`AGENT_HEADLESS=1`): stop here. The runner prints a `claude --resume` command.
- **Interactive**: ask with AskUserQuestion. The options are Approve (commit, push, PR),
  Request changes, and Abort.
  - **Request changes**: apply the requested changes and go back to step 4.
  - **Abort**: leave the branch as is. Run `rm .agent/active` and stop.

## 8. Ship (only after explicit approval)
1. `git add -A` (include the spec file), then `git commit` with a conventional message.
   The pre-commit hook (gitleaks) must pass. Never use `--no-verify`. If it fires, stop and
   ask the user.
2. `git push -u origin <branch>`
3. `gh pr create --base main --head <branch> --title "<commit subject>" --body <body>`.
   The body has the spec objective, the acceptance checklist, the gate summary and
   `Spec: <path>`.
4. `scripts/spec-branch.sh --done`. Print the PR URL.
