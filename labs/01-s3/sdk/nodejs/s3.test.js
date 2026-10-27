import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { mockClient } from 'aws-sdk-client-mock';
import {
  CreateBucketCommand,
  DeleteBucketCommand,
  DeleteObjectsCommand,
  DeleteObjectCommand,
  ListBucketsCommand,
  ListMultipartUploadsCommand,
  ListObjectVersionsCommand,
  AbortMultipartUploadCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import * as s3 from './s3.js';

const mock = mockClient(S3Client);
const clientIn = (region) => new S3Client({ region });
let client;

beforeEach(() => {
  mock.reset();
  client = clientIn('eu-north-1');
});

test('listBuckets returns names', async () => {
  mock.on(ListBucketsCommand).resolves({ Buckets: [{ Name: 'a' }, { Name: 'b' }] });
  assert.deepEqual(await s3.listBuckets(client), ['a', 'b']);
});

test('listBuckets handles no buckets', async () => {
  mock.on(ListBucketsCommand).resolves({});
  assert.deepEqual(await s3.listBuckets(client), []);
});

test('listBuckets propagates SDK failure', async () => {
  mock.on(ListBucketsCommand).rejects(new Error('boom'));
  await assert.rejects(s3.listBuckets(client), /boom/);
});

test('createBucket sends LocationConstraint outside us-east-1', async () => {
  mock.on(CreateBucketCommand).resolves({});
  await s3.createBucket(client, 'b');
  assert.deepEqual(mock.commandCalls(CreateBucketCommand)[0].args[0].input, {
    Bucket: 'b',
    CreateBucketConfiguration: { LocationConstraint: 'eu-north-1' },
  });
});

test('createBucket omits LocationConstraint in us-east-1', async () => {
  mock.on(CreateBucketCommand).resolves({});
  await s3.createBucket(clientIn('us-east-1'), 'b');
  assert.deepEqual(mock.commandCalls(CreateBucketCommand)[0].args[0].input, { Bucket: 'b' });
});

test('createBucket propagates SDK failure', async () => {
  mock.on(CreateBucketCommand).rejects(new Error('exists'));
  await assert.rejects(s3.createBucket(client, 'b'), /exists/);
});

test('deleteBucket happy path and failure', async () => {
  mock.on(DeleteBucketCommand).resolves({});
  assert.deepEqual(await s3.deleteBucket(client, 'b'), { bucket: 'b' });
  mock.on(DeleteBucketCommand).rejects(new Error('not empty'));
  await assert.rejects(s3.deleteBucket(client, 'b'), /not empty/);
});

test('deleteBucket --force removes versions, markers and multipart uploads, in batches', async () => {
  const Versions = Array.from({ length: 1000 }, (_, i) => ({ Key: `k${i}`, VersionId: `v${i}` }));
  mock
    .on(ListObjectVersionsCommand)
    .resolvesOnce({ Versions, IsTruncated: true, NextKeyMarker: 'k999', NextVersionIdMarker: 'v999' })
    .resolvesOnce({ Versions: [{ Key: 'a', VersionId: 'v' }], DeleteMarkers: [{ Key: 'a', VersionId: 'dm' }] });
  mock.on(ListMultipartUploadsCommand).resolves({ Uploads: [{ Key: 'big', UploadId: 'u1' }] });
  mock.on(AbortMultipartUploadCommand).resolves({});
  mock.on(DeleteObjectsCommand).resolves({});
  mock.on(DeleteBucketCommand).resolves({});
  assert.deepEqual(await s3.deleteBucket(client, 'b', { force: true }), { bucket: 'b', deleted: 1002, abortedUploads: 1 });
  const calls = mock.commandCalls(DeleteObjectsCommand).map((c) => c.args[0].input.Delete.Objects);
  assert.deepEqual(calls.map((o) => o.length), [1000, 2]);
  assert.deepEqual(calls[1][1], { Key: 'a', VersionId: 'dm' });
  assert.equal(mock.commandCalls(ListObjectVersionsCommand)[1].args[0].input.VersionIdMarker, 'v999');
  assert.equal(mock.commandCalls(AbortMultipartUploadCommand)[0].args[0].input.UploadId, 'u1');
  assert.equal(mock.commandCalls(DeleteBucketCommand).length, 1);
});

test('deleteBucket --force follows multipart upload pagination', async () => {
  mock.on(ListObjectVersionsCommand).resolves({});
  mock
    .on(ListMultipartUploadsCommand)
    .resolvesOnce({ Uploads: [{ Key: 'a', UploadId: '1' }], IsTruncated: true, NextKeyMarker: 'a', NextUploadIdMarker: '1' })
    .resolvesOnce({ Uploads: [{ Key: 'b', UploadId: '2' }] });
  mock.on(AbortMultipartUploadCommand).resolves({});
  mock.on(DeleteBucketCommand).resolves({});
  const r = await s3.deleteBucket(client, 'b', { force: true });
  assert.equal(r.abortedUploads, 2);
  assert.equal(mock.commandCalls(DeleteObjectsCommand).length, 0);
});

test('deleteBucket without force never lists or empties', async () => {
  mock.on(DeleteBucketCommand).resolves({});
  await s3.deleteBucket(client, 'b');
  assert.equal(mock.commandCalls(ListObjectVersionsCommand).length, 0);
});

test('deleteBucket --force fails and keeps the bucket if object deletion reports errors', async () => {
  mock.on(ListObjectVersionsCommand).resolves({ Versions: [{ Key: 'k', VersionId: 'v' }] });
  mock.on(DeleteObjectsCommand).resolves({ Errors: [{ Key: 'k', Message: 'denied' }] });
  await assert.rejects(s3.deleteBucket(client, 'b', { force: true }), /Failed to delete k: denied/);
  assert.equal(mock.commandCalls(DeleteBucketCommand).length, 0);
});

test('listObjects follows pagination', async () => {
  mock
    .on(ListObjectsV2Command)
    .resolvesOnce({ Contents: [{ Key: 'k1' }], IsTruncated: true, NextContinuationToken: 't1' })
    .resolvesOnce({ Contents: [{ Key: 'k2' }], IsTruncated: false });
  assert.deepEqual(await s3.listObjects(client, 'b', 'p/'), ['k1', 'k2']);
  const calls = mock.commandCalls(ListObjectsV2Command);
  assert.equal(calls.length, 2);
  assert.equal(calls[1].args[0].input.ContinuationToken, 't1');
  assert.equal(calls[0].args[0].input.Prefix, 'p/');
});

test('listObjects handles empty bucket and failure', async () => {
  mock.on(ListObjectsV2Command).resolves({});
  assert.deepEqual(await s3.listObjects(client, 'b'), []);
  mock.on(ListObjectsV2Command).rejects(new Error('denied'));
  await assert.rejects(s3.listObjects(client, 'b'), /denied/);
});

test('putObject happy path and failure', async () => {
  mock.on(PutObjectCommand).resolves({});
  assert.deepEqual(await s3.putObject(client, 'b', 'k', 'data'), { bucket: 'b', key: 'k' });
  assert.equal(mock.commandCalls(PutObjectCommand)[0].args[0].input.Body, 'data');
  mock.on(PutObjectCommand).rejects(new Error('nope'));
  await assert.rejects(s3.putObject(client, 'b', 'k', 'x'), /nope/);
});

test('deleteObject happy path and failure', async () => {
  mock.on(DeleteObjectCommand).resolves({});
  assert.deepEqual(await s3.deleteObject(client, 'b', 'k'), { bucket: 'b', key: 'k' });
  mock.on(DeleteObjectCommand).rejects(new Error('nope'));
  await assert.rejects(s3.deleteObject(client, 'b', 'k'), /nope/);
});

async function makeDir() {
  const dir = await mkdtemp(join(tmpdir(), 's3sync-'));
  await writeFile(join(dir, 'same.txt'), 'abc');
  await writeFile(join(dir, 'changed.txt'), 'abcdef');
  await mkdir(join(dir, 'sub'));
  await writeFile(join(dir, 'sub', 'new.txt'), 'x');
  return dir;
}

test('syncDir uploads missing/different-size files and skips the rest', async () => {
  const dir = await makeDir();
  mock.on(ListObjectsV2Command).resolves({
    Contents: [
      { Key: 'pre/same.txt', Size: 3 },
      { Key: 'pre/changed.txt', Size: 1 },
      { Key: 'pre/extra.txt', Size: 9 },
    ],
  });
  mock.on(PutObjectCommand).resolves({});
  assert.deepEqual(await s3.syncDir(client, dir, 'b', 'pre'), { uploaded: 2, skipped: 1 });
  const keys = mock.commandCalls(PutObjectCommand).map((c) => c.args[0].input.Key).sort((a, b) => a.localeCompare(b));
  assert.deepEqual(keys, ['pre/changed.txt', 'pre/sub/new.txt']);
  assert.equal(mock.commandCalls(DeleteObjectCommand).length, 0);
});

test('syncDir without prefix uses bare relative keys', async () => {
  const dir = await makeDir();
  mock.on(ListObjectsV2Command).resolves({});
  mock.on(PutObjectCommand).resolves({});
  assert.deepEqual(await s3.syncDir(client, dir, 'b'), { uploaded: 3, skipped: 0 });
});

test('syncDir propagates SDK failure', async () => {
  const dir = await makeDir();
  mock.on(ListObjectsV2Command).resolves({});
  mock.on(PutObjectCommand).rejects(new Error('put failed'));
  await assert.rejects(s3.syncDir(client, dir, 'b'), /put failed/);
});
