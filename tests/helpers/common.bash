# Shared bats setup. In a test file:  load helpers/common ; setup() { setup_aws_mock; }
# shellcheck shell=bash

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
export REPO_ROOT

# Put the fake aws first on PATH with a per-test copy of the default fixtures,
# so a test can override a response without affecting others:
#   mock_aws sts get-caller-identity '{"Account":"111111111111","Arn":"x"}' [exit-code]
setup_aws_mock() {
  export AWS_MOCK_DIR="$BATS_TEST_TMPDIR/aws-mock"
  export AWS_MOCK_LOG="$BATS_TEST_TMPDIR/aws-calls.log"
  mkdir -p "$AWS_MOCK_DIR"
  cp "$REPO_ROOT"/tests/fixtures/aws/* "$AWS_MOCK_DIR"/ 2>/dev/null || true
  : >"$AWS_MOCK_LOG"
  PATH="$REPO_ROOT/tests/helpers/bin:$PATH"
  export AWS_PROFILE=default AWS_REGION=eu-north-1
  unset AWS_DEFAULT_REGION
}

mock_aws() {
  local key="$1_$2"
  printf '%s\n' "$3" >"$AWS_MOCK_DIR/$key.out"
  echo "${4:-0}" >"$AWS_MOCK_DIR/$key.exit"
}

# Assert the fake aws was called with args containing $1.
assert_aws_called() {
  grep -qF -- "$1" "$AWS_MOCK_LOG" || { echo "aws not called with: $1"; cat "$AWS_MOCK_LOG"; return 1; }
}
