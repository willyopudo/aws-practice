from datetime import datetime, timezone

import pytest
from botocore.exceptions import ClientError

import s3_lab

B, K = "bkt", "dir/a.txt"
HELLO_MD5 = "5d41402abc4b2a76b9719d911017c592"
HELLO_SHA256 = "LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ="
HELLO_CRC32 = "NhCmhg=="
HELLO_SHA1 = "qvTGHdzF6KLavt4PO0gs2a6pQ00="
ABCDEF_2PART_ETAG = "4c8e93283780e078db9e0c6b9b3f8043-2"


@pytest.fixture
def hello(tmp_path):
    p = tmp_path / "hello.txt"
    p.write_bytes(b"hello")
    return str(p)


def fail(s3, op, code="AccessDenied", status=403):
    s3.stubber.add_client_error(op, service_error_code=code, http_status_code=status)


# --- metadata -------------------------------------------------------------

def test_put_with_metadata(s3):
    s3.stubber.add_response(
        "put_object",
        {},
        {"Bucket": B, "Key": K, "Body": b"x", "Metadata": {"Owner": "me"}, "ContentType": "text/plain"},
    )
    s3_lab.put_with_metadata(s3, B, K, b"x", {"Owner": "me"}, "text/plain")


def test_put_with_metadata_defaults(s3):
    s3.stubber.add_response("put_object", {}, {"Bucket": B, "Key": K, "Body": b"x", "Metadata": {}})
    s3_lab.put_with_metadata(s3, B, K, b"x")


def test_put_with_metadata_error(s3):
    fail(s3, "put_object")
    with pytest.raises(ClientError):
        s3_lab.put_with_metadata(s3, B, K, b"x")


def test_head_object_info(s3):
    s3.stubber.add_response(
        "head_object",
        {
            "Metadata": {"owner": "me"},
            "ContentType": "text/plain",
            "ContentLength": 5,
            "ETag": '"%s"' % HELLO_MD5,
            "ChecksumSHA256": HELLO_SHA256,
            "VersionId": "v1",
        },
        {"Bucket": B, "Key": K, "ChecksumMode": "ENABLED"},
    )
    assert s3_lab.head_object_info(s3, B, K) == {
        "metadata": {"owner": "me"},
        "content_type": "text/plain",
        "size": 5,
        "etag": HELLO_MD5,
        "checksum": {"SHA256": HELLO_SHA256},
        "version_id": "v1",
    }


def test_head_object_info_no_checksum(s3):
    s3.stubber.add_response("head_object", {"ContentLength": 0}, {"Bucket": B, "Key": K, "ChecksumMode": "ENABLED"})
    info = s3_lab.head_object_info(s3, B, K)
    assert info["checksum"] is None and info["metadata"] == {}


def test_head_object_info_error(s3):
    fail(s3, "head_object", "404", 404)
    with pytest.raises(ClientError):
        s3_lab.head_object_info(s3, B, K)


# --- checksum -------------------------------------------------------------

def test_put_with_checksum_default_sha256(s3):
    s3.stubber.add_response(
        "put_object", {}, {"Bucket": B, "Key": K, "Body": b"x", "ChecksumAlgorithm": "SHA256", "Metadata": {}}
    )
    s3_lab.put_with_checksum(s3, B, K, b"x")


def test_put_with_checksum_error(s3):
    fail(s3, "put_object", "InvalidRequest", 400)
    with pytest.raises(ClientError):
        s3_lab.put_with_checksum(s3, B, K, b"x", "CRC32")


@pytest.mark.parametrize(
    "algo,expected",
    [("SHA256", HELLO_SHA256), ("CRC32", HELLO_CRC32), ("SHA1", HELLO_SHA1), ("CRC32C", None)],
)
def test_local_checksum(hello, algo, expected):
    assert s3_lab.local_checksum(hello, algo) == expected


def head_resp(etag=HELLO_MD5, **extra):
    resp = {"ETag": '"%s"' % etag, "ContentLength": 5}
    resp.update(extra)
    return resp


def stub_head(s3, resp, **params):
    s3.stubber.add_response("head_object", resp, dict({"Bucket": B, "Key": K}, **params))


def test_verify_object_match(s3, hello):
    stub_head(s3, head_resp(ChecksumSHA256=HELLO_SHA256), ChecksumMode="ENABLED")
    out = s3_lab.verify_object(s3, B, K, hello)
    assert out["ok"] and out["checksum_match"] and out["etag_match"]
    assert out["checksum_algorithm"] == "SHA256"


def test_verify_object_checksum_mismatch(s3, hello):
    stub_head(s3, head_resp(ChecksumCRC32="AAAAAA=="), ChecksumMode="ENABLED")
    out = s3_lab.verify_object(s3, B, K, hello)
    assert out["checksum_match"] is False and out["ok"] is False


def test_verify_object_etag_mismatch_no_checksum(s3, hello):
    stub_head(s3, head_resp(etag="0" * 32), ChecksumMode="ENABLED")
    out = s3_lab.verify_object(s3, B, K, hello)
    assert out["checksum_match"] is None and out["etag_match"] is False and out["ok"] is False


def test_verify_object_unsupported_algorithm(s3, hello):
    stub_head(s3, head_resp(ChecksumCRC32C="AAAAAA=="), ChecksumMode="ENABLED")
    out = s3_lab.verify_object(s3, B, K, hello)
    assert out["checksum_match"] is None and out["ok"] is True


def test_verify_object_multipart_etag(s3, tmp_path):
    p = tmp_path / "f"
    p.write_bytes(b"abcdef")
    stub_head(s3, head_resp(etag=ABCDEF_2PART_ETAG, ContentLength=6), ChecksumMode="ENABLED")
    stub_head(s3, head_resp(ContentLength=3), PartNumber=1)
    out = s3_lab.verify_object(s3, B, K, str(p))
    assert out["etag_match"] and out["local_etag"] == ABCDEF_2PART_ETAG


def test_verify_object_error(s3, hello):
    fail(s3, "head_object", "404", 404)
    with pytest.raises(ClientError):
        s3_lab.verify_object(s3, B, K, hello)


# --- etag -----------------------------------------------------------------

def test_local_etag_single_part(hello):
    assert s3_lab.local_etag(hello) == HELLO_MD5


def test_local_etag_two_parts(tmp_path):
    p = tmp_path / "f"
    p.write_bytes(b"abcdef")
    assert s3_lab.local_etag(str(p), part_size=3) == ABCDEF_2PART_ETAG


def test_local_etag_part_size_larger_than_file(hello):
    assert s3_lab.local_etag(hello, part_size=1024) == HELLO_MD5


def test_local_etag_empty_file(tmp_path):
    p = tmp_path / "e"
    p.write_bytes(b"")
    assert s3_lab.local_etag(str(p), part_size=3) == "d41d8cd98f00b204e9800998ecf8427e"


def test_local_etag_missing_file(tmp_path):
    with pytest.raises(OSError):
        s3_lab.local_etag(str(tmp_path / "nope"))


# --- prefixes -------------------------------------------------------------

def test_list_level_paginates(s3):
    params = {"Bucket": B, "Prefix": "a/", "Delimiter": "/"}
    s3.stubber.add_response(
        "list_objects_v2",
        {"IsTruncated": True, "NextContinuationToken": "t", "CommonPrefixes": [{"Prefix": "a/b/"}]},
        params,
    )
    s3.stubber.add_response(
        "list_objects_v2",
        {"CommonPrefixes": [{"Prefix": "a/c/"}], "Contents": [{"Key": "a/x.txt"}]},
        dict(params, ContinuationToken="t"),
    )
    assert s3_lab.list_level(s3, B, "a/") == {"prefixes": ["a/b/", "a/c/"], "keys": ["a/x.txt"]}


def test_list_level_empty_root(s3):
    s3.stubber.add_response("list_objects_v2", {}, {"Bucket": B, "Prefix": "", "Delimiter": "/"})
    assert s3_lab.list_level(s3, B) == {"prefixes": [], "keys": []}


def test_list_level_error(s3):
    fail(s3, "list_objects_v2", "NoSuchBucket", 404)
    with pytest.raises(ClientError):
        s3_lab.list_level(s3, B)


# --- object lock ----------------------------------------------------------

def test_create_lock_bucket_eu_north_1(s3):
    s3.stubber.add_response(
        "create_bucket",
        {},
        {
            "Bucket": B,
            "ObjectLockEnabledForBucket": True,
            "CreateBucketConfiguration": {"LocationConstraint": "eu-north-1"},
        },
    )
    assert s3_lab.create_lock_bucket(s3, B)["object_lock"] is True


def test_create_lock_bucket_us_east_1_has_no_location_constraint(s3):
    s3.meta.config.region_name = "us-east-1"
    s3.meta._region_name = "us-east-1"
    s3.stubber.add_response("create_bucket", {}, {"Bucket": B, "ObjectLockEnabledForBucket": True})
    s3_lab.create_lock_bucket(s3, B)


def test_create_bucket_without_lock(s3):
    s3.stubber.add_response(
        "create_bucket", {}, {"Bucket": B, "CreateBucketConfiguration": {"LocationConstraint": "eu-north-1"}}
    )
    assert s3_lab.create_bucket(s3, B)["object_lock"] is False


def test_create_lock_bucket_error(s3):
    fail(s3, "create_bucket", "BucketAlreadyExists", 409)
    with pytest.raises(ClientError):
        s3_lab.create_lock_bucket(s3, B)


def test_put_with_retention_governance(s3):
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    s3.stubber.add_response(
        "put_object_retention",
        {},
        {
            "Bucket": B,
            "Key": K,
            "Retention": {"Mode": "GOVERNANCE", "RetainUntilDate": datetime(2026, 1, 2, tzinfo=timezone.utc)},
        },
    )
    out = s3_lab.put_with_retention(s3, B, K, now=now)
    assert out["mode"] == "GOVERNANCE" and out["retain_until"].startswith("2026-01-02")


def test_put_with_retention_default_clock(s3):
    s3.stubber.add_response("put_object_retention", {})
    assert s3_lab.put_with_retention(s3, B, K, days=3)["mode"] == "GOVERNANCE"


def test_put_with_retention_error(s3):
    fail(s3, "put_object_retention", "InvalidRequest", 400)
    with pytest.raises(ClientError):
        s3_lab.put_with_retention(s3, B, K)


@pytest.mark.parametrize("on,status", [(True, "ON"), (False, "OFF")])
def test_set_legal_hold(s3, on, status):
    s3.stubber.add_response(
        "put_object_legal_hold", {}, {"Bucket": B, "Key": K, "LegalHold": {"Status": status}}
    )
    assert s3_lab.set_legal_hold(s3, B, K, on)["legal_hold"] == status


def test_set_legal_hold_error(s3):
    fail(s3, "put_object_legal_hold")
    with pytest.raises(ClientError):
        s3_lab.set_legal_hold(s3, B, K, True)


# --- teardown -------------------------------------------------------------

def stub_versions(s3, **resp):
    s3.stubber.add_response("list_object_versions", resp, {"Bucket": B})


def test_teardown_locked_bucket(s3):
    s3.stubber.add_response("get_object_lock_configuration", {}, {"Bucket": B})
    stub_versions(
        s3,
        Versions=[{"Key": "a", "VersionId": "1"}],
        DeleteMarkers=[{"Key": "a", "VersionId": "2"}],
    )
    s3.stubber.add_response(
        "put_object_legal_hold",
        {},
        {"Bucket": B, "Key": "a", "VersionId": "1", "LegalHold": {"Status": "OFF"}},
    )
    s3.stubber.add_response(
        "delete_objects",
        {},
        {
            "Bucket": B,
            "Delete": {
                "Objects": [{"Key": "a", "VersionId": "1"}, {"Key": "a", "VersionId": "2"}],
                "Quiet": True,
            },
            "BypassGovernanceRetention": True,
        },
    )
    s3.stubber.add_response("delete_bucket", {}, {"Bucket": B})
    assert s3_lab.teardown(s3, B) == {"bucket": B, "deleted_versions": 2, "bucket_deleted": True}


def test_teardown_without_object_lock_skips_legal_hold(s3):
    fail(s3, "get_object_lock_configuration", "ObjectLockConfigurationNotFoundError", 404)
    stub_versions(s3, Versions=[{"Key": "a", "VersionId": "1"}])
    s3.stubber.add_response("delete_objects", {})
    s3.stubber.add_response("delete_bucket", {}, {"Bucket": B})
    assert s3_lab.teardown(s3, B)["deleted_versions"] == 1


def test_teardown_empty_bucket(s3):
    fail(s3, "get_object_lock_configuration", "ObjectLockConfigurationNotFoundError", 404)
    stub_versions(s3)
    s3.stubber.add_response("delete_bucket", {}, {"Bucket": B})
    assert s3_lab.teardown(s3, B)["deleted_versions"] == 0


def test_teardown_lock_check_error(s3):
    fail(s3, "get_object_lock_configuration")
    with pytest.raises(ClientError):
        s3_lab.teardown(s3, B)


def test_teardown_delete_errors_raise(s3):
    fail(s3, "get_object_lock_configuration", "ObjectLockConfigurationNotFoundError", 404)
    stub_versions(s3, Versions=[{"Key": "a", "VersionId": "1"}])
    s3.stubber.add_response(
        "delete_objects", {"Errors": [{"Key": "a", "Code": "AccessDenied", "Message": "no bypass"}]}
    )
    with pytest.raises(ClientError, match="no bypass"):
        s3_lab.teardown(s3, B)
