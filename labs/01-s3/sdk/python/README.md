# S3 SDK lab (Python / boto3)

Metadata, additional checksums, ETags, prefixes and Object Lock. Account `395931907369`,
region `eu-north-1` (run `./scripts/whoami.sh` first). Cost: a few tiny objects, free tier.

## Setup
```
cd labs/01-s3/sdk/python
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/pytest -q          # stubbed, no AWS calls
```
Region and credentials come from the default boto3 chain. Exit codes: 1 usage, 2 SDK error, 3 verify mismatch.

## Demo order (use `.venv/bin/python cli.py ...`; bucket names are global, pick your own)
```
cli.py create-bucket my-lock-bkt --lock                                # 1
cli.py put my-lock-bkt dir/a.txt a.txt --meta Owner=me --checksum SHA256   # 2
cli.py head my-lock-bkt dir/a.txt                                      # 3 note lowercased "owner"
cli.py verify my-lock-bkt dir/a.txt a.txt                              # 4 checksum + ETag match
cli.py prefixes my-lock-bkt                                            # 5 -> "dir/"
cli.py etag a.txt --part-size-mb 8                                     # local ETag, no AWS call
cli.py retain my-lock-bkt dir/a.txt --days 1                           # 6 GOVERNANCE
cli.py legal-hold my-lock-bkt dir/a.txt on                             #   and off
aws s3api delete-object --bucket my-lock-bkt --key dir/a.txt --version-id <id from head>   # 7 fails
cli.py teardown my-lock-bkt                                            # 8 bypasses GOVERNANCE
```
Step 7 is denied while retention or a legal hold is active. Teardown clears holds, deletes
every version and delete marker with `BypassGovernanceRetention`, then deletes the bucket
(needs `s3:BypassGovernanceRetention`). It also works on a bucket without Object Lock.
