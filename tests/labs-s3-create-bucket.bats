#!/usr/bin/env bats
load helpers/common

setup() {
  setup_aws_mock
  SCRIPT="$REPO_ROOT/labs/01-s3/bash-scripts/create-bucket.sh"
}

@test "creates bucket with LocationConstraint outside us-east-1 and tags it" {
  run "$SCRIPT" my-bucket
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Created s3://my-bucket in eu-north-1"* ]]
  assert_aws_called "s3api create-bucket --bucket my-bucket --region eu-north-1 --create-bucket-configuration LocationConstraint=eu-north-1"
  assert_aws_called "s3api put-bucket-tagging --bucket my-bucket --tagging TagSet=[{Key=Project,Value=aws-practice},{Key=Lab,Value=s3}]"
}

@test "omits LocationConstraint in us-east-1" {
  AWS_REGION=us-east-1 run "$SCRIPT" my-bucket
  [ "$status" -eq 0 ]
  [[ "$output" == *"in us-east-1"* ]]
  assert_aws_called "s3api create-bucket --bucket my-bucket --region us-east-1"
  ! grep -q "LocationConstraint" "$AWS_MOCK_LOG"
}

@test "falls back to the configured region when no env region is set" {
  unset AWS_REGION
  mock_aws configure get "ap-south-1"
  run "$SCRIPT" my-bucket
  [ "$status" -eq 0 ]
  assert_aws_called "LocationConstraint=ap-south-1"
}

@test "defaults to eu-north-1 when no region is configured" {
  unset AWS_REGION
  run "$SCRIPT" my-bucket
  [ "$status" -eq 0 ]
  assert_aws_called "LocationConstraint=eu-north-1"
}

@test "usage error with wrong arg count" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
  run "$SCRIPT" a b
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
  ! grep -q "s3api" "$AWS_MOCK_LOG"
}

@test "fails when create-bucket fails and does not tag" {
  mock_aws s3api create-bucket "" 254
  run "$SCRIPT" my-bucket
  [ "$status" -eq 254 ]
  ! grep -q "put-bucket-tagging" "$AWS_MOCK_LOG"
}

@test "refuses to run against a non-practice account" {
  mock_aws sts get-caller-identity '{"Account":"111111111111","Arn":"arn:aws:iam::111111111111:user/x"}'
  run "$SCRIPT" my-bucket
  [ "$status" -eq 1 ]
  [[ "$output" == *"Account guard failed"* ]]
  ! grep -q "s3api" "$AWS_MOCK_LOG"
}
