"""S3 behaviours via boto3: metadata, checksums, ETags, prefixes, Object Lock.

Every function takes a boto3 S3 client first. Region and credentials come from the
default boto3 chain; nothing is hard-coded.
"""
import base64
import hashlib
import zlib
from datetime import datetime, timedelta, timezone

from botocore.exceptions import ClientError

CHECKSUM_FIELDS = {
    "CRC32": "ChecksumCRC32",
    "CRC32C": "ChecksumCRC32C",
    "CRC64NVME": "ChecksumCRC64NVME",
    "SHA1": "ChecksumSHA1",
    "SHA256": "ChecksumSHA256",
}
_CHUNK = 1024 * 1024


def _read_chunks(path, size=_CHUNK):
    with open(path, "rb") as f:
        while True:
            chunk = f.read(size)
            if not chunk:
                return
            yield chunk


def put_with_metadata(client, bucket, key, body, metadata=None, content_type=None):
    """Upload bytes with user metadata. S3 lowercases the metadata keys."""
    kwargs = {"Bucket": bucket, "Key": key, "Body": body, "Metadata": metadata or {}}
    if content_type:
        kwargs["ContentType"] = content_type
    return client.put_object(**kwargs)


def head_object_info(client, bucket, key):
    """Metadata, content type, size, ETag and checksum for one object, in one dict."""
    resp = client.head_object(Bucket=bucket, Key=key, ChecksumMode="ENABLED")
    checksum = {algo: resp[field] for algo, field in CHECKSUM_FIELDS.items() if field in resp}
    return {
        "metadata": resp.get("Metadata", {}),
        "content_type": resp.get("ContentType"),
        "size": resp.get("ContentLength"),
        "etag": resp.get("ETag", "").strip('"'),
        "checksum": checksum or None,
        "version_id": resp.get("VersionId"),
    }


def put_with_checksum(client, bucket, key, body, algorithm="SHA256", metadata=None):
    """Upload with an additional checksum; S3 verifies it and stores it with the object."""
    return client.put_object(
        Bucket=bucket,
        Key=key,
        Body=body,
        ChecksumAlgorithm=algorithm,
        Metadata=metadata or {},
    )


def local_checksum(path, algorithm):
    """Base64 checksum of a local file, or None if the algorithm is not in the stdlib."""
    if algorithm == "CRC32":
        value = 0
        for chunk in _read_chunks(path):
            value = zlib.crc32(chunk, value)
        return base64.b64encode(value.to_bytes(4, "big")).decode()
    if algorithm in ("SHA1", "SHA256"):
        digest = hashlib.new(algorithm.lower())
        for chunk in _read_chunks(path):
            digest.update(chunk)
        return base64.b64encode(digest.digest()).decode()
    return None


def local_etag(path, part_size=None):
    """MD5 hex for one part; `<md5-of-part-md5s>-<n>` when split into several parts."""
    if not part_size:
        digest = hashlib.md5()
        for chunk in _read_chunks(path):
            digest.update(chunk)
        return digest.hexdigest()
    part_digests = [hashlib.md5(chunk).digest() for chunk in _read_chunks(path, part_size)]
    if len(part_digests) <= 1:
        return local_etag(path)
    return "%s-%d" % (hashlib.md5(b"".join(part_digests)).hexdigest(), len(part_digests))


def verify_object(client, bucket, key, path):
    """Compare a local file with the remote checksum and ETag.

    `*_match` is None when it cannot be compared (no remote checksum, or an algorithm
    the stdlib cannot compute). `ok` is True when nothing compared mismatched.
    """
    resp = client.head_object(Bucket=bucket, Key=key, ChecksumMode="ENABLED")
    remote_etag = resp.get("ETag", "").strip('"')

    algorithm = remote_value = local_value = checksum_match = None
    for algo, field in CHECKSUM_FIELDS.items():
        if field in resp:
            algorithm, remote_value = algo, resp[field]
            break
    if algorithm:
        local_value = local_checksum(path, algorithm)
        if local_value is not None:
            checksum_match = local_value == remote_value

    part_size = None
    if "-" in remote_etag:
        part_size = client.head_object(Bucket=bucket, Key=key, PartNumber=1)["ContentLength"]
    local = local_etag(path, part_size)

    etag_match = local == remote_etag
    return {
        "checksum_algorithm": algorithm,
        "checksum_match": checksum_match,
        "local_checksum": local_value,
        "remote_checksum": remote_value,
        "etag_match": etag_match,
        "local_etag": local,
        "remote_etag": remote_etag,
        "ok": checksum_match is not False and etag_match,
    }


def list_level(client, bucket, prefix=""):
    """One level of the key space: common prefixes ("folders") and keys under `prefix`."""
    prefixes, keys = [], []
    paginator = client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix, Delimiter="/"):
        prefixes += [p["Prefix"] for p in page.get("CommonPrefixes", [])]
        keys += [o["Key"] for o in page.get("Contents", [])]
    return {"prefixes": prefixes, "keys": keys}


def create_bucket(client, bucket, lock=False):
    """Create a bucket; `lock=True` enables Object Lock (which also turns on versioning)."""
    kwargs = {"Bucket": bucket}
    if lock:
        kwargs["ObjectLockEnabledForBucket"] = True
    region = client.meta.region_name
    if region and region != "us-east-1":
        kwargs["CreateBucketConfiguration"] = {"LocationConstraint": region}
    client.create_bucket(**kwargs)
    return {"bucket": bucket, "region": region, "object_lock": lock}


def create_lock_bucket(client, bucket):
    return create_bucket(client, bucket, lock=True)


def put_with_retention(client, bucket, key, days=1, now=None):
    """GOVERNANCE retention only: removable with s3:BypassGovernanceRetention."""
    until = (now or datetime.now(timezone.utc)) + timedelta(days=days)
    client.put_object_retention(
        Bucket=bucket,
        Key=key,
        Retention={"Mode": "GOVERNANCE", "RetainUntilDate": until},
    )
    return {"bucket": bucket, "key": key, "mode": "GOVERNANCE", "retain_until": until.isoformat()}


def set_legal_hold(client, bucket, key, on):
    status = "ON" if on else "OFF"
    client.put_object_legal_hold(Bucket=bucket, Key=key, LegalHold={"Status": status})
    return {"bucket": bucket, "key": key, "legal_hold": status}


def _has_object_lock(client, bucket):
    try:
        client.get_object_lock_configuration(Bucket=bucket)
    except ClientError as err:
        if err.response["Error"]["Code"] == "ObjectLockConfigurationNotFoundError":
            return False
        raise
    return True


def teardown(client, bucket):
    """Delete every version and delete marker, then the bucket. Destructive."""
    locked = _has_object_lock(client, bucket)
    deleted = 0
    for page in client.get_paginator("list_object_versions").paginate(Bucket=bucket):
        versions = page.get("Versions", [])
        markers = page.get("DeleteMarkers", [])
        if locked:
            for v in versions:
                client.put_object_legal_hold(
                    Bucket=bucket,
                    Key=v["Key"],
                    VersionId=v["VersionId"],
                    LegalHold={"Status": "OFF"},
                )
        targets = [{"Key": o["Key"], "VersionId": o["VersionId"]} for o in versions + markers]
        if not targets:
            continue
        resp = client.delete_objects(
            Bucket=bucket,
            Delete={"Objects": targets, "Quiet": True},
            BypassGovernanceRetention=True,
        )
        errors = resp.get("Errors")
        if errors:
            raise ClientError(
                {"Error": {"Code": errors[0]["Code"], "Message": errors[0]["Message"]}},
                "DeleteObjects",
            )
        deleted += len(targets)
    client.delete_bucket(Bucket=bucket)
    return {"bucket": bucket, "deleted_versions": deleted, "bucket_deleted": True}
