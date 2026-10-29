#!/usr/bin/env bats
load helpers/common

# Static checks only — no terraform init/plan/apply, so nothing can reach real AWS.
setup() {
  TF_DIR="$REPO_ROOT/labs/01-s3/iac/terraform"
}

@test "terraform files are formatted" {
  command -v terraform >/dev/null || skip "terraform not installed"
  run terraform fmt -check -recursive "$TF_DIR"
  [ "$status" -eq 0 ]
}

@test "provider is locked to the practice account" {
  grep -q 'allowed_account_ids = \[var.practice_account_id\]' "$TF_DIR/providers.tf"
  grep -q 'default *= "395931907369"' "$TF_DIR/variables.tf"
}

@test "default region is eu-north-1" {
  grep -A4 'variable "region"' "$TF_DIR/variables.tf" | grep -q 'default *= "eu-north-1"'
}

@test "default_tags carry Project and a Lab tag matching the directory" {
  grep -q 'Project *= "aws-practice"' "$TF_DIR/providers.tf"
  grep -q 'Lab *= "01-s3"' "$TF_DIR/providers.tf"
}

@test "provider version is pinned and the lock file is present" {
  grep -q 'version = "~> 6.0"' "$TF_DIR/providers.tf"
  grep -q 'version = "~> 3.6"' "$TF_DIR/providers.tf"
  [ -f "$TF_DIR/.terraform.lock.hcl" ]
}

@test "bucket is destroyable in one command and blocks public access" {
  grep -q 'force_destroy = true' "$TF_DIR/main.tf"
  for opt in block_public_acls block_public_policy ignore_public_acls restrict_public_buckets; do
    grep -q "$opt *= true" "$TF_DIR/main.tf"
  done
}

@test "bucket name gets a 5-letter lowercase random suffix" {
  block="$(awk '/resource "random_string" "suffix"/,/^}/' "$TF_DIR/main.tf")"
  grep -q 'length *= 5' <<<"$block"
  grep -q 'upper *= false' <<<"$block"
  grep -q 'numeric *= false' <<<"$block"
  grep -q 'special *= false' <<<"$block"
  grep -q 'random_string.suffix.result' "$TF_DIR/main.tf"
}

@test "no credentials or tfvars in the lab" {
  [ -z "$(find "$REPO_ROOT/labs/01-s3/iac" -name '*.tfvars*' -not -path '*/.terraform/*')" ]
  ! grep -rEq 'AKIA[0-9A-Z]{16}' "$REPO_ROOT/labs/01-s3/iac" --exclude-dir=.terraform --exclude-dir=node_modules --exclude-dir=cdk.out
}
