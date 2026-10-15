#!/usr/bin/env bats
load helpers/common

# Run new-lab.sh inside a throwaway copy of the repo layout, never the real labs/.
setup() {
  setup_aws_mock
  FAKE_ROOT="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FAKE_ROOT/scripts" "$FAKE_ROOT/labs"
  cp -R "$REPO_ROOT/labs/_template" "$FAKE_ROOT/labs/_template"
  ln -s "$REPO_ROOT/scripts/new-lab.sh" "$FAKE_ROOT/scripts/new-lab.sh"
  SCRIPT="$FAKE_ROOT/scripts/new-lab.sh"
  find "$REPO_ROOT/labs" -maxdepth 1 >"$BATS_TEST_TMPDIR/labs-before"
}

teardown() {
  find "$REPO_ROOT/labs" -maxdepth 1 | diff "$BATS_TEST_TMPDIR/labs-before" -
}

@test "creates the first lab with the name substituted" {
  run "$SCRIPT" s3-static-site
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Created labs/01-s3-static-site"* ]]
  lab="$FAKE_ROOT/labs/01-s3-static-site"
  [ -f "$lab/README.md" ]
  grep -q "^# 01-s3-static-site" "$lab/README.md"
  grep -q 'Lab       = "01-s3-static-site"' "$lab/terraform/providers.tf"
  ! grep -rq "__LAB_NAME__" "$lab"
  [ -z "$(find "$lab" -name '*.bak')" ]
}

@test "numbers the next lab after existing ones" {
  mkdir -p "$FAKE_ROOT/labs/01-first" "$FAKE_ROOT/labs/02-second"
  run "$SCRIPT" vpc
  [ "$status" -eq 0 ]
  [ -d "$FAKE_ROOT/labs/03-vpc" ]
}

@test "usage error without a name" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage:"* ]]
}

@test "refuses to overwrite an existing lab" {
  # A gap in numbering: one lab exists, so the next number (02) collides with it.
  mkdir -p "$FAKE_ROOT/labs/02-dup"
  run "$SCRIPT" dup
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
  [ -z "$(ls -A "$FAKE_ROOT/labs/02-dup")" ]
}
