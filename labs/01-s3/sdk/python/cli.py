"""CLI for s3_lab. Exit codes: 0 ok, 1 usage error, 2 SDK error, 3 verify mismatch."""
import argparse
import json
import sys

import boto3
from botocore.exceptions import BotoCoreError, ClientError

import s3_lab

CHECKSUM_ALGOS = list(s3_lab.CHECKSUM_FIELDS)


class _Parser(argparse.ArgumentParser):
    def error(self, message):
        self.print_usage(sys.stderr)
        self.exit(1, "%s: error: %s\n" % (self.prog, message))


def _meta_pair(text):
    key, sep, value = text.partition("=")
    if not sep or not key:
        raise argparse.ArgumentTypeError("expected k=v, got %r" % text)
    return key, value


def build_parser():
    p = _Parser(prog="cli.py", description="S3 SDK lab")
    sub = p.add_subparsers(dest="cmd", required=True, parser_class=_Parser)

    c = sub.add_parser("create-bucket")
    c.add_argument("bucket")
    c.add_argument("--lock", action="store_true", help="enable Object Lock")

    c = sub.add_parser("put")
    c.add_argument("bucket")
    c.add_argument("key")
    c.add_argument("file")
    c.add_argument("--meta", nargs="+", action="extend", type=_meta_pair, default=[])
    c.add_argument("--checksum", choices=CHECKSUM_ALGOS)

    c = sub.add_parser("head")
    c.add_argument("bucket")
    c.add_argument("key")

    c = sub.add_parser("etag")
    c.add_argument("file")
    c.add_argument("--part-size-mb", type=int)

    c = sub.add_parser("verify")
    c.add_argument("bucket")
    c.add_argument("key")
    c.add_argument("file")

    c = sub.add_parser("prefixes")
    c.add_argument("bucket")
    c.add_argument("prefix", nargs="?", default="")

    c = sub.add_parser("retain")
    c.add_argument("bucket")
    c.add_argument("key")
    c.add_argument("--days", type=int, default=1)

    c = sub.add_parser("legal-hold")
    c.add_argument("bucket")
    c.add_argument("key")
    c.add_argument("state", choices=["on", "off"])

    c = sub.add_parser("teardown")
    c.add_argument("bucket")
    return p


def _run(args, client):
    cmd = args.cmd
    if cmd == "etag":
        part = args.part_size_mb * 1024 * 1024 if args.part_size_mb else None
        return {"etag": s3_lab.local_etag(args.file, part)}
    client = client or boto3.client("s3")
    if cmd == "create-bucket":
        return s3_lab.create_bucket(client, args.bucket, args.lock)
    if cmd == "put":
        with open(args.file, "rb") as f:
            body = f.read()
        meta = dict(args.meta)
        if args.checksum:
            s3_lab.put_with_checksum(client, args.bucket, args.key, body, args.checksum, meta)
        else:
            s3_lab.put_with_metadata(client, args.bucket, args.key, body, meta)
        return s3_lab.head_object_info(client, args.bucket, args.key)
    if cmd == "head":
        return s3_lab.head_object_info(client, args.bucket, args.key)
    if cmd == "verify":
        return s3_lab.verify_object(client, args.bucket, args.key, args.file)
    if cmd == "prefixes":
        return s3_lab.list_level(client, args.bucket, args.prefix)
    if cmd == "retain":
        return s3_lab.put_with_retention(client, args.bucket, args.key, args.days)
    if cmd == "legal-hold":
        return s3_lab.set_legal_hold(client, args.bucket, args.key, args.state == "on")
    return s3_lab.teardown(client, args.bucket)


def main(argv=None, client=None):
    args = build_parser().parse_args(argv)
    try:
        result = _run(args, client)
    except OSError as err:
        print("error: %s" % err, file=sys.stderr)
        return 1
    except (ClientError, BotoCoreError) as err:
        print("error: %s" % err, file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, default=str))
    if args.cmd == "verify" and not result["ok"]:
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
