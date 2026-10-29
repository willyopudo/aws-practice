---
id: 003-s3-cdk-typescript
coverage_min: 70
sonar: true
max_iterations: 5
max_turns: 40
max_budget_usd: 3
model: sonnet
---

# S3 bucket with AWS CDK (TypeScript)

## Objective
Add a minimal AWS CDK (TypeScript) app in `labs/01-s3/iac/cdk/` that creates one S3 bucket
and can be torn down with one command. It is the CDK counterpart to the Terraform lab in
`labs/01-s3/iac/terraform/`.

## Acceptance criteria
- [x] One stack, `S3LabStack`, creates exactly one `AWS::S3::Bucket`: versioning off, public access fully blocked, encryption on (S3-managed).
- [x] The bucket is disposable: `removalPolicy: DESTROY` and `autoDeleteObjects: true`, so `cdk destroy` succeeds even when the bucket has objects.
- [x] The bucket name is not hard-coded (CloudFormation generates it). The stack outputs it as `BucketName`.
- [x] Every resource is tagged `Project = aws-practice` and `Lab = 01-s3-cdk` (app-level `Tags.of(app)`).
- [x] Account and region come from the default credential chain (`CDK_DEFAULT_ACCOUNT` / `CDK_DEFAULT_REGION`). Nothing is hard-coded.
- [x] `package.json` pins CDK versions (no `^`) and has scripts `build` and `test` (jest). Deploy and teardown use the plain CDK CLI (`cdk synth`, `cdk deploy`, `cdk destroy`), with `aws-cdk` as a pinned devDependency run via `npx`; no wrapper scripts.
- [x] Tests use `Template.fromStack` from `aws-cdk-lib/assertions`: bucket count, public access block, encryption, removal policy, tags, output. They never call AWS.
- [x] `README.md` in the lab dir (under 30 lines): prerequisites, `./scripts/whoami.sh` check, `cdk bootstrap`, `cdk deploy`, `cdk destroy`.
- [x] `cdk.out/`, `node_modules/` and compiled JS are gitignored; `package-lock.json` is committed.
- [x] Quality gate passes (`scripts/quality-gate.sh`).

## Scope
- `labs/01-s3/iac/cdk/` only (source, tests, `package.json`, `cdk.json`, `tsconfig.json`, `README.md`, `.gitignore`).
- `notes/s3.md`: add a short "CDK vs Terraform" section.

## Out of scope
- No `cdk deploy`, `cdk bootstrap` or `cdk destroy` during the spec run. The human runs these after approval.
- No real AWS calls. No lifecycle rules, bucket policies, replication, CloudFront or Lambda (beyond the one CDK itself adds for `autoDeleteObjects`).
- No CDK Pipelines, no multiple stacks or stages, no context lookups.
- No changes to `scripts/`, `tests/helpers/`, `labs/01-s3/bash-scripts/` or the Terraform lab.

## Notes
- Region is `eu-north-1`. `cdk bootstrap` creates a small `CDKToolkit` stack (free); mention it in the README.
- CDK deploy is blocked for agents (`bash-guard.sh` blocks `terraform apply`; the same rule applies in spirit). Deploy is a live-demo step.
