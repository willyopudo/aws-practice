#!/usr/bin/env bats
load helpers/common

setup() {
  setup_aws_mock
  SCRIPT="$REPO_ROOT/labs/s3/bash-scripts/put-object.sh"
  FILE="$BATS_TEST_TMPDIR/hello.txt"
  echo hello >"$FILE"
}

@test "uploads using the file basename as key" {
  run "$SCRIPT" my-bucket "$FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"→ s3://my-bucket/hello.txt"* ]]
  assert_aws_called "s3api put-object --bucket my-bucket --key hello.txt --body $FILE"
}

@test "uploads with an explicit key" {
  run "$SCRIPT" my-bucket "$FILE" docs/greeting.txt
  [ "$status" -eq 0 ]
  assert_aws_called "s3api put-object --bucket my-bucket --key docs/greeting.txt"
}

@test "usage error with wrong arg count" {
  run "$SCRIPT" my-bucket
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
  run "$SCRIPT" a b c d
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "fails when the file does not exist" {
  run "$SCRIPT" my-bucket "$BATS_TEST_TMPDIR/missing.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"File not found"* ]]
  [ ! -s "$AWS_MOCK_LOG" ]
}

@test "fails when put-object fails" {
  mock_aws s3api put-object "" 1
  run "$SCRIPT" my-bucket "$FILE"
  [ "$status" -eq 1 ]
  [[ "$output" != *"✓ Uploaded"* ]]
}
