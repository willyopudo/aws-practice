#!/usr/bin/env bats
load helpers/common

setup() {
  setup_aws_mock
  SCRIPT="$REPO_ROOT/labs/01-s3/bash-scripts/list-objects.sh"
}

@test "lists objects as a table" {
  mock_aws s3api list-objects-v2 "| key.txt | 12 |"
  run "$SCRIPT" my-bucket
  [ "$status" -eq 0 ]
  [[ "$output" == *"| key.txt | 12 |"* ]]
  assert_aws_called "s3api list-objects-v2 --bucket my-bucket --query"
  assert_aws_called "--output table"
  ! grep -q -- "--prefix" "$AWS_MOCK_LOG"
}

@test "passes a prefix through" {
  run "$SCRIPT" my-bucket logs/
  [ "$status" -eq 0 ]
  assert_aws_called "s3api list-objects-v2 --bucket my-bucket --prefix logs/"
}

@test "usage error with wrong arg count" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
  run "$SCRIPT" a b c
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "fails when list-objects-v2 fails" {
  mock_aws s3api list-objects-v2 "" 255
  run "$SCRIPT" my-bucket
  [ "$status" -eq 255 ]
}
