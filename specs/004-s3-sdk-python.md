---
id: 004-s3-sdk-python
coverage_min: 80
sonar: true
max_iterations: 5
max_turns: 60
max_budget_usd: 3
model: sonnet
---

# S3 SDK lab (Python): metadata, checksums, ETag, prefixes, Object Lock

## Objective
Add a small Python lab in `labs/01-s3/sdk/python/` that uses boto3 to show five S3 behaviours:
user metadata, additional checksums, ETags, prefixes, and Object Lock. One module, one CLI,
one teardown command.

## Acceptance criteria
- [ ] `s3_lab.py` exports one function per behaviour, each taking a boto3 S3 client as its first argument:
      `put_with_metadata`, `head_object_info`, `put_with_checksum`, `local_etag`, `verify_object`,
      `list_level`, `create_lock_bucket`, `put_with_retention`, `set_legal_hold`, `teardown`.
- [ ] Metadata: `put_with_metadata` stores `Metadata={...}`; `head_object_info` returns metadata, content type, size, ETag and checksum in one dict.
- [ ] Checksum: `put_with_checksum` sends `ChecksumAlgorithm` (default `SHA256`); `verify_object` recomputes the base64 checksum of a local file and compares it with `head_object(ChecksumMode="ENABLED")`.
- [ ] ETag: `local_etag(path, part_size=None)` returns the MD5 hex digest for a single part, and `<md5-of-part-md5s>-<n>` for multipart. `verify_object` reports whether it matches the remote ETag.
- [ ] Prefixes: `list_level(client, bucket, prefix="")` uses `Delimiter="/"` and follows pagination. It returns `{"prefixes": [...], "keys": [...]}`.
- [ ] Object Lock: `create_lock_bucket` sets `ObjectLockEnabledForBucket=True` and handles `eu-north-1` (`LocationConstraint`).
      `put_with_retention` uses `GOVERNANCE` mode only, with `days` default 1. `set_legal_hold` toggles `ON`/`OFF`.
- [ ] Teardown: `teardown(client, bucket)` deletes every object version and delete marker with `BypassGovernanceRetention=True`, clears legal holds first, then deletes the bucket. It works on a bucket without Object Lock.
- [ ] `cli.py` (argparse) subcommands: `create-bucket <bucket> [--lock]`, `put <bucket> <key> <file> [--meta k=v ...] [--checksum ALGO]`,
      `head <bucket> <key>`, `etag <file> [--part-size-mb N]`, `verify <bucket> <key> <file>`, `prefixes <bucket> [prefix]`,
      `retain <bucket> <key> [--days N]`, `legal-hold <bucket> <key> on|off`, `teardown <bucket>`.
      Results print as JSON. Usage error exits 1, SDK error exits 2, `verify` mismatch exits 3.
- [ ] Region and credentials come from the default boto3 chain. Nothing is hard-coded.
- [ ] Tests (`pytest`) use `botocore.stub.Stubber`. No network, no real AWS calls.
      Each function is covered for the happy path and one `ClientError`. `local_etag` is also tested against known MD5 values for single-part and two-part inputs.
- [ ] `requirements.txt` (`boto3`) and `requirements-dev.txt` (`pytest`, `pytest-cov`), both pinned.
- [ ] `README.md` under 50 lines: setup, one example command per subcommand, and the order for the demo (create-bucket `--lock`, put, head, verify, prefixes, retain, a delete that fails, teardown).
- [ ] `requirements-dev.txt` is what makes `make test` and `make coverage` pick the lab up (venv, `pytest`, `--cov-fail-under`). Do not edit the Makefile.
- [ ] Line coverage ≥ 80% for the lab (`make coverage`).
- [ ] Quality gate passes (`scripts/quality-gate.sh`).

## Scope
- `labs/01-s3/sdk/python/` only (source, tests, requirements, `README.md`).
- `notes/s3.md`: add a short section on metadata keys being lowercased, ETag is not always MD5, and Object Lock needing versioning.

## Out of scope
- No real AWS calls in tests. No COMPLIANCE mode, no default bucket retention, no presigned URLs, no multipart upload code (compute the multipart ETag locally only).
- No TypeScript, no web page, no extra CLI frameworks.
- No changes to `scripts/`, `tests/helpers/`, other labs, or the workflow tooling.

## Notes
- Cost: S3 free tier, a few tiny objects. Run only in account `395931907369`, region `eu-north-1` (confirm with `./scripts/whoami.sh`).
- Object Lock buckets cannot be deleted until locked versions are removed. That is why `teardown` bypasses GOVERNANCE retention, which needs `s3:BypassGovernanceRetention`.
