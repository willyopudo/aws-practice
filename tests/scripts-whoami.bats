#!/usr/bin/env bats
load helpers/common

setup() {
  setup_aws_mock
  SCRIPT="$REPO_ROOT/scripts/whoami.sh"
}

@test "confirms the practice account" {
  mock_aws configure get "eu-north-1"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"account : 395931907369"* ]]
  [[ "$output" == *"region  : eu-north-1"* ]]
  [[ "$output" == *"✓ Practice account confirmed."* ]]
  assert_aws_called "sts get-caller-identity --profile default --output json"
}

@test "exits 2 on a non-practice account" {
  mock_aws sts get-caller-identity '{"Account":"111111111111","Arn":"arn:aws:iam::111111111111:user/someone"}'
  run "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"account : 111111111111"* ]]
  [[ "$output" == *"STOP. This is NOT the practice account"* ]]
}

@test "uses AWS_PROFILE and reports unset region" {
  echo 1 >"$AWS_MOCK_DIR/configure_get.exit"  # no region configured
  AWS_PROFILE=other run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"profile : other"* ]]
  [[ "$output" == *"region  : unset"* ]]
  assert_aws_called "sts get-caller-identity --profile other"
}

@test "exits 1 when the caller identity call fails" {
  mock_aws sts get-caller-identity "Unable to locate credentials" 255
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not get caller identity for profile 'default'"* ]]
  [[ "$output" == *"Unable to locate credentials"* ]]
}
