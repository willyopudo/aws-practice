import json

import pytest
from botocore.exceptions import ClientError, EndpointConnectionError

import cli

HELLO_MD5 = "5d41402abc4b2a76b9719d911017c592"
HEAD_PARAMS = {"Bucket": "b", "Key": "k", "ChecksumMode": "ENABLED"}
HEAD_RESP = {"ETag": '"%s"' % HELLO_MD5, "ContentLength": 5, "ContentType": "text/plain"}


@pytest.fixture
def hello(tmp_path):
    p = tmp_path / "hello.txt"
    p.write_bytes(b"hello")
    return str(p)


def run(capsys, argv, client=None):
    code = cli.main(argv, client)
    return code, capsys.readouterr()


def test_usage_error_exits_1(capsys):
    code = pytest.raises(SystemExit, cli.main, ["nope"]).value.code
    assert code == 1
    assert "usage" in capsys.readouterr().err


def test_bad_meta_exits_1(capsys, hello):
    with pytest.raises(SystemExit) as exc:
        cli.main(["put", "b", "k", hello, "--meta", "novalue"])
    assert exc.value.code == 1


def test_etag_single_and_multipart(capsys, hello):
    code, out = run(capsys, ["etag", hello])
    assert code == 0 and json.loads(out.out) == {"etag": HELLO_MD5}
    code, out = run(capsys, ["etag", hello, "--part-size-mb", "1"])
    assert json.loads(out.out)["etag"] == HELLO_MD5


def test_etag_missing_file_exits_1(capsys, tmp_path):
    code, out = run(capsys, ["etag", str(tmp_path / "nope")])
    assert code == 1 and "error" in out.err


def test_create_bucket_plain(capsys, s3):
    s3.stubber.add_response(
        "create_bucket",
        {},
        {"Bucket": "b", "CreateBucketConfiguration": {"LocationConstraint": "eu-north-1"}},
    )
    code, out = run(capsys, ["create-bucket", "b"], s3)
    assert code == 0 and json.loads(out.out)["object_lock"] is False


def test_create_bucket_lock(capsys, s3):
    s3.stubber.add_response("create_bucket", {})
    code, out = run(capsys, ["create-bucket", "b", "--lock"], s3)
    assert code == 0 and json.loads(out.out)["object_lock"] is True


def test_put_with_meta_prints_head(capsys, s3, hello):
    s3.stubber.add_response(
        "put_object", {}, {"Bucket": "b", "Key": "k", "Body": b"hello", "Metadata": {"a": "1", "c": "2"}}
    )
    s3.stubber.add_response("head_object", HEAD_RESP, HEAD_PARAMS)
    code, out = run(capsys, ["put", "b", "k", hello, "--meta", "a=1", "c=2"], s3)
    assert code == 0 and json.loads(out.out)["size"] == 5


def test_put_with_checksum(capsys, s3, hello):
    s3.stubber.add_response(
        "put_object",
        {},
        {"Bucket": "b", "Key": "k", "Body": b"hello", "ChecksumAlgorithm": "CRC32", "Metadata": {}},
    )
    s3.stubber.add_response("head_object", HEAD_RESP, HEAD_PARAMS)
    assert run(capsys, ["put", "b", "k", hello, "--checksum", "CRC32"], s3)[0] == 0


def test_head(capsys, s3):
    s3.stubber.add_response("head_object", HEAD_RESP, HEAD_PARAMS)
    code, out = run(capsys, ["head", "b", "k"], s3)
    assert json.loads(out.out)["etag"] == HELLO_MD5


def test_verify_ok_and_mismatch(capsys, s3, hello):
    s3.stubber.add_response("head_object", HEAD_RESP, HEAD_PARAMS)
    assert run(capsys, ["verify", "b", "k", hello], s3)[0] == 0
    s3.stubber.add_response("head_object", dict(HEAD_RESP, ETag='"%s"' % ("0" * 32)), HEAD_PARAMS)
    assert run(capsys, ["verify", "b", "k", hello], s3)[0] == 3


def test_prefixes(capsys, s3):
    s3.stubber.add_response(
        "list_objects_v2", {"CommonPrefixes": [{"Prefix": "p/"}]}, {"Bucket": "b", "Prefix": "", "Delimiter": "/"}
    )
    code, out = run(capsys, ["prefixes", "b"], s3)
    assert json.loads(out.out) == {"prefixes": ["p/"], "keys": []}


def test_retain(capsys, s3):
    s3.stubber.add_response("put_object_retention", {})
    code, out = run(capsys, ["retain", "b", "k", "--days", "2"], s3)
    assert json.loads(out.out)["mode"] == "GOVERNANCE"


def test_legal_hold(capsys, s3):
    s3.stubber.add_response("put_object_legal_hold", {}, {"Bucket": "b", "Key": "k", "LegalHold": {"Status": "ON"}})
    code, out = run(capsys, ["legal-hold", "b", "k", "on"], s3)
    assert json.loads(out.out)["legal_hold"] == "ON"


def test_teardown(capsys, s3):
    s3.stubber.add_client_error("get_object_lock_configuration", "ObjectLockConfigurationNotFoundError", http_status_code=404)
    s3.stubber.add_response("list_object_versions", {}, {"Bucket": "b"})
    s3.stubber.add_response("delete_bucket", {}, {"Bucket": "b"})
    code, out = run(capsys, ["teardown", "b"], s3)
    assert code == 0 and json.loads(out.out)["bucket_deleted"] is True


def test_client_error_exits_2(capsys, s3):
    s3.stubber.add_client_error("head_object", "404", http_status_code=404)
    code, out = run(capsys, ["head", "b", "k"], s3)
    assert code == 2 and "error" in out.err


def test_botocore_error_exits_2(capsys, monkeypatch):
    class Boom:
        def head_object(self, **_):
            raise EndpointConnectionError(endpoint_url="http://x")

    code, _ = run(capsys, ["head", "b", "k"], Boom())
    assert code == 2


def test_default_client_comes_from_boto3(capsys, monkeypatch, s3):
    s3.stubber.add_response("head_object", HEAD_RESP, HEAD_PARAMS)
    monkeypatch.setattr(cli.boto3, "client", lambda name: s3)
    assert run(capsys, ["head", "b", "k"])[0] == 0
