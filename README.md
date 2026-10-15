# aws-practice

Sandbox for learning AWS hands-on. Terraform + AWS CLI, everything disposable.

**Target account: `395931907369`** (`default` profile, `eu-north-1`) — personal, isolated
from the One Acre Fund org accounts (`acc-dev`, `acc-prod`, `acc-uat`, `acc-qa`,
`shared-infra`). Every lab hard-codes `allowed_account_ids`, so Terraform physically
refuses to apply into an org account.

## First run

```bash
./scripts/whoami.sh                                   # confirm the account
cd 00-setup/terraform
terraform init
terraform apply -var="alert_email=you@example.com"    # $10 budget + alerts
```

Then do the three console toggles listed in `00-setup/README.md` (Free Tier alerts,
Cost Explorer, MFA on `aws-iam-user`).

## Daily loop

```bash
./scripts/new-lab.sh s3-static-site     # scaffolds labs/01-s3-static-site
cd labs/01-s3-static-site/terraform
terraform init && terraform plan && terraform apply
# ...learn, poke at it with the CLI, write up notes/...
terraform destroy
cd - && ./scripts/sweep.sh              # prove nothing is left running
```

## Layout

```
00-setup/        account baseline — budget + alerts. Apply once, leave up.
labs/            one directory per topic. Create, learn, destroy.
  _template/     copied by scripts/new-lab.sh
01-cli-scratch/  throwaway CLI experiments, gitignored output
notes/           what I learned, per service
scripts/         whoami / sweep / new-lab
```

## Scripts

| Script | Does |
|---|---|
| `./scripts/whoami.sh` | Prints the active identity. **Exits non-zero if it is not the practice account** — chain it before destructive commands. |
| `./scripts/sweep.sh [--all]` | Hunts for leftover billable resources (EC2, NAT GW, LBs, idle EIPs, RDS, EKS, detached EBS, S3). `--all` scans every region. |
| `./scripts/new-lab.sh <name>` | Scaffolds a numbered lab from the template. |
| `./scripts/install-hooks.sh` | Enables the gitleaks pre-commit hook. Run once after cloning. |

## Secret scanning

A **gitleaks pre-commit hook** blocks any commit containing a secret. It scans only the
staged diff, so it runs in well under a second.

Enabled via `core.hooksPath = .githooks`, which means the hook is **version-controlled**
and comes back automatically on a fresh clone — you just run `./scripts/install-hooks.sh`
once to point git at it.

```bash
./scripts/install-hooks.sh                        # one-time
gitleaks git --config .gitleaks.toml .            # scan full history, any time
```

Tuning lives in `.gitleaks.toml`: the full built-in ruleset (~170 patterns) plus narrow
allowlists for things that are safe here — the practice account id, Terraform lock files,
and AWS's own documented example keys.

### Private patterns

Some things are not "secrets" to gitleaks but still should not be committed: real IAM
usernames, internal hostnames, One Acre Fund org account ids. Those go in
**`.secrets-patterns.local`** — one regex per line, **gitignored**. The hook blocks any
staged file matching one, and reports the *file* without echoing the matching line.

The gitignore is the whole point: putting these in `.gitleaks.toml` would commit the
exact string you are trying to keep out. `.secrets-patterns.local.example` is the tracked
placeholder; `install-hooks.sh` copies it on a fresh clone.

If it fires on a **real** secret: unstage it, remove the value, and **rotate the
credential** — anything written to disk should be treated as already compromised. If it
fires on a **false positive**: add a narrow rule to `.gitleaks.toml` or append
`# gitleaks:allow` to that line. `git commit --no-verify` bypasses the hook; it exists for
emergencies, not for silencing findings.

## Cost rules

The expensive mistakes, in order of how often they happen:

| Resource | Cost if forgotten | Notes |
|---|---|---|
| EKS cluster | ~$73/mo | Control plane bills even with zero nodes. |
| NAT Gateway | ~$32/mo | Plus data processing. Use a public subnet for labs. |
| ALB / NLB | ~$16/mo | Bills hourly from creation. |
| RDS instance | varies | Free tier is 750h/mo of `db.t3.micro` — *one* instance. |
| Unattached Elastic IP | ~$3.60/mo | Only billed when **not** attached. Easy to miss. |
| Detached EBS volume | ~$0.08/GB/mo | `terraform destroy` misses these if created outside TF. |

Free-tier friendly for labs: S3, Lambda, DynamoDB on-demand, SQS, SNS, CloudWatch Logs,
IAM, VPC itself (subnets/route tables/IGW/SGs are free), API Gateway, Step Functions.

## Suggested path

Rough order, each one builds on the last:

1. **IAM** — users, roles, policies, assume-role. Everything else depends on this.
2. **S3** — buckets, policies, static site hosting, versioning, lifecycle.
3. **VPC** — subnets, route tables, IGW, security groups vs NACLs. All free.
4. **EC2** — launch, SSM Session Manager (no SSH keys), instance profiles.
5. **Lambda + API Gateway** — the serverless core.
6. **DynamoDB** — single-table design, on-demand billing.
7. **SQS / SNS / EventBridge** — decoupling and events.
8. **CloudWatch** — logs, metrics, alarms.
9. **RDS** — when relational is the right call.
10. **ECS Fargate** — containers without managing nodes.

## Tooling

Installed and verified: `aws-cli 2.37`, `terraform 1.16` (HashiCorp tap — it is no longer
in homebrew-core), `uv 0.13`, Docker, Node 24, Git.

VS Code picks up `.vscode/settings.json` (format-on-save for `.tf`, the account id in the
window title) and will prompt to install the extensions in `.vscode/extensions.json`.
