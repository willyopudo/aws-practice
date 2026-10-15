#!/usr/bin/env bats
load helpers/common

setup() {
  setup_aws_mock
  SCRIPT="$REPO_ROOT/labs/s3/bash-scripts/delete-object.sh"
}

@test "deletes an object" {
  run "$SCRIPT" my-bucket path/key.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Deleted s3://my-bucket/path/key.txt"* ]]
  [[ "$output" != *"(version"* ]]
  assert_aws_called "s3api delete-object --bucket my-bucket --key path/key.txt"
  ! grep -q -- "--version-id" "$AWS_MOCK_LOG"
}

@test "deletes a specific version" {
  run "$SCRIPT" my-bucket key.txt v123
  [ "$status" -eq 0 ]
  [[ "$output" == *"(version v123)"* ]]
  assert_aws_called "s3api delete-object --bucket my-bucket --key key.txt --version-id v123"
}

@test "usage error with wrong arg count" {
  run "$SCRIPT" my-bucket
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
  run "$SCRIPT" a b c d
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "fails when delete-object fails" {
  mock_aws s3api delete-object "" 1
  run "$SCRIPT" my-bucket key.txt
  [ "$status" -eq 1 ]
  [[ "$output" != *"✓ Deleted"* ]]
}
