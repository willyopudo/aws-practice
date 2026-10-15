#!/usr/bin/env bats
load helpers/common

setup() {
  setup_aws_mock
  SCRIPT="$REPO_ROOT/labs/s3/bash-scripts/delete-bucket.sh"
}

# list-object-versions returns one page of objects, then an empty page.
mock_versions_once() {
  local page='{"Objects":[{"Key":"a.txt","VersionId":"v1"},{"Key":"b.txt","VersionId":"v2"}],"Quiet":true}'
  local wrapper="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$wrapper"
  printf '%s\n' "$page" >"$AWS_MOCK_DIR/page1"
  cat >"$wrapper/aws" <<WRAP
#!/usr/bin/env bash
if [[ "\$1 \$2" == "s3api list-object-versions" ]]; then
  if [[ -f "$AWS_MOCK_DIR/page1" ]]; then
    printf '%s\n' "\$*" >>"$AWS_MOCK_LOG"
    cat "$AWS_MOCK_DIR/page1"; rm "$AWS_MOCK_DIR/page1"; exit 0
  fi
fi
exec "$REPO_ROOT/tests/helpers/bin/aws" "\$@"
WRAP
  chmod +x "$wrapper/aws"
  PATH="$wrapper:$PATH"
  mock_aws s3api list-object-versions '{"Objects":null,"Quiet":true}'
}

@test "deletes an empty bucket" {
  run "$SCRIPT" my-bucket
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Deleted s3://my-bucket"* ]]
  assert_aws_called "s3api delete-bucket --bucket my-bucket"
  ! grep -q "list-object-versions" "$AWS_MOCK_LOG"
}

@test "--force empties every version then deletes the bucket" {
  mock_versions_once
  run "$SCRIPT" my-bucket --force <<<"y"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted 2 object version(s)"* ]]
  [[ "$output" == *"✓ Deleted s3://my-bucket"* ]]
  assert_aws_called "s3api list-object-versions --bucket my-bucket --max-items 500"
  assert_aws_called 's3api delete-objects --bucket my-bucket --delete {"Objects":[{"Key":"a.txt"'
  assert_aws_called "s3api delete-bucket --bucket my-bucket"
  [ "$(grep -c 'list-object-versions' "$AWS_MOCK_LOG")" -eq 2 ]
}

@test "--force aborts unless confirmed" {
  run "$SCRIPT" my-bucket --force <<<"n"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Aborted."* ]]
  ! grep -q "s3api" "$AWS_MOCK_LOG"
}

@test "usage error with wrong arg count" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
  run "$SCRIPT" a --force extra
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "rejects an unknown option" {
  run "$SCRIPT" my-bucket --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option: --yes"* ]]
}

@test "fails when delete-bucket fails" {
  mock_aws s3api delete-bucket "" 254
  echo "An error occurred (BucketNotEmpty)" >"$AWS_MOCK_DIR/s3api_delete-bucket.err"
  run "$SCRIPT" my-bucket
  [ "$status" -eq 254 ]
  [[ "$output" == *"BucketNotEmpty"* ]]
  [[ "$output" != *"✓ Deleted"* ]]
}
