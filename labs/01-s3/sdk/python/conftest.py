import boto3
import pytest
from botocore.stub import Stubber


@pytest.fixture
def s3():
    client = boto3.client(
        "s3",
        region_name="eu-north-1",
        aws_access_key_id="testing",
        aws_secret_access_key="testing",
    )
    with Stubber(client) as stubber:
        client.stubber = stubber
        yield client
        stubber.assert_no_pending_responses()
