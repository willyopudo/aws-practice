# aws-practice

A personal sandbox for learning AWS. Every resource here is disposable.

## Account & profile rules — read before any AWS call

- **All practice resources go in account `395931907369`** (IAM user `aws-iam-user`, the
  `default` profile, region `eu-north-1`). The account is on the AWS Free Plan, whose SCP
  denies `us-east-1`; revisit this after upgrading to a paid plan.
- The profiles `acc-dev`, `acc-prod`, `acc-uat`, `acc-qa`, `shared-infra` are **real One Acre
  Fund org accounts**. Never create, modify, or delete anything in them from this directory.
  Read-only inspection is fine if explicitly asked.
- Before any command that creates or destroys, confirm the target with
  `./scripts/whoami.sh` and check the account number is `395931907369`.

## Cost discipline

This is a personal account paying real money. Treat cost as a correctness constraint.

- Prefer free-tier / always-free resources. Call out the cost of anything that is not.
- **Never** create without a teardown path. Each lab must be destroyable with one command.
- Flag these before creating them: NAT Gateway (~$32/mo), ALB/NLB (~$16/mo), RDS instances,
  EKS control plane (~$73/mo), Elastic IPs left unattached, `aws-managed` VPC endpoints,
  anything in a region other than `eu-north-1`.
- Run `./scripts/sweep.sh` to find leftover billable resources across regions.

## Layout

| Path | Purpose |
|---|---|
| `00-setup/` | One-time account baseline (budget alarm, cost guardrails). Long-lived. |
| `labs/<nn>-<topic>/` | One self-contained lab per AWS topic. Create, learn, destroy. |
| `labs/_template/` | Copy this to start a new lab. |
| `01-cli-scratch/` | Throwaway CLI experiments. Nothing here is permanent. |
| `notes/` | Markdown notes per service — what I learned, gotchas, exam facts. |
| `scripts/` | Safety + housekeeping helpers. |

## Terraform conventions

- Terraform runs from inside a single lab directory, never from the repo root.
- Local state only (`terraform.tfstate` stays on disk, gitignored). No remote backend —
  these labs are disposable and a shared backend adds cost and friction.
- Every lab inherits `provider "aws" { default_tags }` with `Project = "aws-practice"` and
  `Lab = "<lab-name>"`. This is what makes `sweep.sh` and manual cleanup possible — do not
  drop it.
- Pin the provider version. Commit `.terraform.lock.hcl`.

## Secrets

- A gitleaks pre-commit hook (`.githooks/pre-commit`) blocks commits containing secrets.
  **Never bypass it with `git commit --no-verify`** to get a commit through — if it fires,
  either the finding is real (remove and rotate the credential) or the allowlist in
  `.gitleaks.toml` needs a narrow addition. Ask before doing either.
- Never write credentials into a `.tf`, `.sh`, or notes file, even as a placeholder that
  "looks real". Use variables, env vars, or the AWS credential chain — Terraform and the
  CLI both pick up the `default` profile without being told.
- `*.tfvars` is gitignored because it is the usual place secrets end up. Keep it that way.
- **Do not write real IAM usernames or One Acre Fund org account ids into tracked files.**
  Use generic placeholders (`aws-iam-user`, `<org-account-id>`). The practice account id
  `395931907369` is the deliberate exception — it is the account guard.
  `.secrets-patterns.local` (gitignored) holds the real values and the hook blocks them.

## Working style

- When teaching a service, show the CLI command first, then the Terraform equivalent.
  The CLI builds intuition; Terraform builds the habit.
- Put the "why" in `notes/<service>.md`, not in code comments.
- After finishing a lab, run `terraform destroy` and say so explicitly in the summary.

## Agentic workflow (spec runs)

- Specs live in `specs/` (copy `specs/_template.md`). Run one with `/spec-run specs/<file>.md`,
  or headless with `scripts/agent-run.sh specs/<file>.md`. The loop is in `.claude/skills/spec-run/`.
- Every spec runs on its own branch (`scripts/spec-branch.sh`); never commit to `main`.
- Done means `scripts/quality-gate.sh` passes. Read its summary, not raw tool output.
- Commit, push and PR need explicit user approval. Tests never call real AWS (`tests/helpers/`).
