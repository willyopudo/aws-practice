import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile } from 'node:fs/promises';
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
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { run } from './cli.js';

const mock = mockClient(S3Client);
let client;
let out;
let err;
const exec = (...argv) => run(argv, client, (s) => out.push(s), (s) => err.push(s));

beforeEach(() => {
  mock.reset();
  client = new S3Client({ region: 'eu-north-1' });
  out = [];
  err = [];
});

test('no command prints usage to stderr, exit 1', async () => {
  assert.equal(await exec(), 1);
  assert.match(err[0], /Usage/);
});

test('unknown command and wrong arg count exit 1', async () => {
  assert.equal(await exec('nope'), 1);
  assert.equal(await exec('create-bucket'), 1);
  assert.equal(await exec('list-buckets', 'extra'), 1);
  assert.equal(out.length, 0);
});

test('SDK error prints message to stderr, exit 2', async () => {
  mock.on(ListBucketsCommand).rejects(new Error('denied'));
  assert.equal(await exec('list-buckets'), 2);
  assert.deepEqual(err, ['denied']);
});

test('delete-bucket --force (flag in any position) empties then deletes', async () => {
  mock.on(ListObjectVersionsCommand).resolves({ Versions: [{ Key: 'k', VersionId: 'v' }] });
  mock.on(ListMultipartUploadsCommand).resolves({});
  mock.on(DeleteObjectsCommand).resolves({});
  mock.on(DeleteBucketCommand).resolves({});
  assert.equal(await exec('delete-bucket', '--force', 'b'), 0);
  assert.equal(mock.commandCalls(DeleteObjectsCommand).length, 1);
  assert.deepEqual(JSON.parse(out[0]), { bucket: 'b', deleted: 1, abortedUploads: 0 });
  assert.equal(await exec('create-bucket', 'b', '--force'), 1);
});

test('every subcommand dispatches and prints to stdout', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'cli-'));
  const file = join(dir, 'f.txt');
  await writeFile(file, 'hi');
  mock.on(ListBucketsCommand).resolves({ Buckets: [{ Name: 'a' }] });
  mock.on(CreateBucketCommand).resolves({});
  mock.on(DeleteBucketCommand).resolves({});
  mock.on(ListObjectsV2Command).resolves({ Contents: [{ Key: 'k', Size: 1 }] });
  mock.on(PutObjectCommand).resolves({});
  mock.on(DeleteObjectCommand).resolves({});

  assert.equal(await exec('list-buckets'), 0);
  assert.equal(await exec('create-bucket', 'b'), 0);
  assert.equal(await exec('delete-bucket', 'b'), 0);
  assert.equal(await exec('list-objects', 'b', 'p'), 0);
  assert.equal(await exec('put-object', 'b', file), 0);
  assert.equal(await exec('put-object', 'b', file, 'custom'), 0);
  assert.equal(await exec('sync', dir, 'b', 'p'), 0);
  assert.equal(await exec('delete-object', 'b', 'k'), 0);

  assert.equal(out.length, 8 + 0);
  assert.deepEqual(JSON.parse(out[0]), ['a']);
  const keys = mock.commandCalls(PutObjectCommand).map((c) => c.args[0].input.Key);
  assert.deepEqual(keys.slice(0, 2), ['f.txt', 'custom']);
});
