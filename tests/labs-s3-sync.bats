#!/usr/bin/env bats
load helpers/common

setup() {
  setup_aws_mock
  SCRIPT="$REPO_ROOT/labs/01-s3/bash-scripts/sync.sh"
  DIR="$BATS_TEST_TMPDIR/data"
  mkdir -p "$DIR"
  echo hi >"$DIR/a.txt"
}

@test "syncs a directory to the bucket root" {
  run "$SCRIPT" my-bucket "$DIR"
  [ "$status" -eq 0 ]
  assert_aws_called "s3 sync $DIR s3://my-bucket/"
  [[ "$output" == *"Synced 1 path(s)"* ]]
}

@test "strips s3:// and trailing slash, keeps prefix" {
  run "$SCRIPT" s3://my-bucket/logs/ "$DIR"
  [ "$status" -eq 0 ]
  assert_aws_called "s3 sync $DIR s3://my-bucket/logs/"
}

@test "syncs a single file with exclude/include" {
  run "$SCRIPT" my-bucket "$DIR/a.txt"
  [ "$status" -eq 0 ]
  assert_aws_called "s3 sync $DIR s3://my-bucket/ --exclude * --include a.txt"
}

@test "passes --dryrun for directories and files" {
  run "$SCRIPT" --dryrun my-bucket "$DIR" "$DIR/a.txt"
  [ "$status" -eq 0 ]
  [ "$(grep -c -- "--dryrun" "$AWS_MOCK_LOG")" -eq 2 ]
}

@test "--delete applies to directories only" {
  run "$SCRIPT" --delete my-bucket "$DIR" "$DIR/a.txt"
  [ "$status" -eq 0 ]
  [ "$(grep -c -- "--delete" "$AWS_MOCK_LOG")" -eq 1 ]
  grep -- "--delete" "$AWS_MOCK_LOG" | grep -qv -- "--include"
}

@test "rejects an unknown flag" {
  run "$SCRIPT" --bogus my-bucket "$DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "usage error with too few args" {
  run "$SCRIPT" my-bucket
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "fails before calling aws when a path is missing" {
  run "$SCRIPT" my-bucket "$DIR/nope"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Not found:"* ]]
  [ ! -s "$AWS_MOCK_LOG" ]
}

@test "stops on a non-practice account" {
  mock_aws sts get-caller-identity '{"Account":"111111111111","Arn":"x"}'
  run "$SCRIPT" my-bucket "$DIR"
  [ "$status" -ne 0 ]
  ! grep -q "s3 sync" "$AWS_MOCK_LOG"
}

@test "fails when sync fails" {
  mock_aws s3 sync "" 1
  run "$SCRIPT" my-bucket "$DIR"
  [ "$status" -eq 1 ]
}
