#!/usr/bin/env bats
load helpers/common

setup() {
  setup_aws_mock
  SCRIPT="$REPO_ROOT/labs/01-s3/bash-scripts/list-buckets.sh"
}

@test "lists bucket names newest first" {
  mock_aws s3api list-buckets '{"Buckets":[{"Name":"old","CreationDate":"2024-01-01T00:00:00+00:00"},{"Name":"new","CreationDate":"2025-01-01T00:00:00+00:00"}]}'
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "new" ]
  [ "${lines[1]}" = "old" ]
  assert_aws_called "s3api list-buckets"
}

@test "prints nothing when there are no buckets" {
  mock_aws s3api list-buckets '{"Buckets":[]}'
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stops on a non-practice account" {
  mock_aws sts get-caller-identity '{"Account":"111111111111","Arn":"x"}'
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  ! grep -q "s3api list-buckets" "$AWS_MOCK_LOG"
}

@test "fails when list-buckets fails" {
  mock_aws s3api list-buckets "" 255
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}
