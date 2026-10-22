import { test, beforeEach, before, after } from 'node:test';
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
import { createServer } from './server.js';

const mock = mockClient(S3Client);
let server;
let base;

before(async () => {
  server = createServer(new S3Client({ region: 'eu-north-1' }));
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());
beforeEach(() => mock.reset());

const call = async (method, path, body, raw) => {
  const res = await fetch(base + path, {
    method,
    body: body === undefined ? undefined : raw ? body : JSON.stringify(body),
  });
  return { status: res.status, json: await res.json() };
};

test('GET / serves index.html', async () => {
  const res = await fetch(`${base}/`);
  assert.equal(res.status, 200);
  assert.match(await res.text(), /S3 lab/);
});

test('unknown routes return 404', async () => {
  assert.equal((await call('GET', '/nope')).status, 404);
  assert.equal((await call('PATCH', '/api/buckets')).status, 404);
});

test('GET /api/buckets: 200 and 500', async () => {
  mock.on(ListBucketsCommand).resolves({ Buckets: [{ Name: 'a' }] });
  assert.deepEqual(await call('GET', '/api/buckets'), { status: 200, json: { buckets: ['a'] } });
  mock.on(ListBucketsCommand).rejects(new Error('boom'));
  assert.deepEqual(await call('GET', '/api/buckets'), { status: 500, json: { error: 'boom' } });
});

test('POST /api/buckets: 200, 400 (missing name, bad JSON), 500', async () => {
  mock.on(CreateBucketCommand).resolves({});
  assert.equal((await call('POST', '/api/buckets', { name: 'b' })).status, 200);
  assert.equal((await call('POST', '/api/buckets', {})).status, 400);
  const bad = await call('POST', '/api/buckets', '{oops', true);
  assert.equal(bad.status, 400);
  mock.on(CreateBucketCommand).rejects(new Error('exists'));
  assert.deepEqual(await call('POST', '/api/buckets', { name: 'b' }), { status: 500, json: { error: 'exists' } });
});

test('DELETE /api/buckets/:bucket: 200, 400, 500', async () => {
  mock.on(DeleteBucketCommand).resolves({});
  assert.equal((await call('DELETE', '/api/buckets/b')).status, 200);
  assert.equal((await call('DELETE', '/api/buckets/%E0%A4%A')).status, 400); // malformed escape
  mock.on(DeleteBucketCommand).rejects(new Error('not empty'));
  assert.deepEqual(await call('DELETE', '/api/buckets/b'), { status: 500, json: { error: 'not empty' } });
});

test('DELETE /api/buckets/:bucket?force=true empties the bucket first', async () => {
  mock.on(ListObjectVersionsCommand).resolves({ Versions: [{ Key: 'k', VersionId: 'v' }] });
  mock.on(ListMultipartUploadsCommand).resolves({});
  mock.on(DeleteObjectsCommand).resolves({});
  mock.on(DeleteBucketCommand).resolves({});
  assert.deepEqual(await call('DELETE', '/api/buckets/b?force=true'), { status: 200, json: { bucket: 'b', deleted: 1, abortedUploads: 0 } });
  assert.equal(mock.commandCalls(DeleteObjectsCommand).length, 1);
  mock.on(DeleteObjectsCommand).rejects(new Error('denied'));
  assert.equal((await call('DELETE', '/api/buckets/b?force=true')).status, 500);
});

test('GET /api/buckets/:bucket/objects: 200 with prefix, 500', async () => {
  mock.on(ListObjectsV2Command).resolves({ Contents: [{ Key: 'p/k' }] });
  assert.deepEqual(await call('GET', '/api/buckets/b/objects?prefix=p/'), { status: 200, json: { objects: ['p/k'] } });
  assert.equal(mock.commandCalls(ListObjectsV2Command)[0].args[0].input.Prefix, 'p/');
  mock.on(ListObjectsV2Command).rejects(new Error('denied'));
  assert.equal((await call('GET', '/api/buckets/b/objects')).status, 500);
});

test('PUT objects: 200 with raw body, 400 without key, 500', async () => {
  mock.on(PutObjectCommand).resolves({});
  const ok = await call('PUT', '/api/buckets/b/objects?key=k.txt', 'hello', true);
  assert.deepEqual(ok, { status: 200, json: { bucket: 'b', key: 'k.txt' } });
  assert.equal(mock.commandCalls(PutObjectCommand)[0].args[0].input.Body.toString(), 'hello');
  assert.equal((await call('PUT', '/api/buckets/b/objects', 'x', true)).status, 400);
  mock.on(PutObjectCommand).rejects(new Error('nope'));
  assert.equal((await call('PUT', '/api/buckets/b/objects?key=k', 'x', true)).status, 500);
});

test('DELETE objects: 200, 400 without key, 500', async () => {
  mock.on(DeleteObjectCommand).resolves({});
  assert.equal((await call('DELETE', '/api/buckets/b/objects?key=k')).status, 200);
  assert.equal((await call('DELETE', '/api/buckets/b/objects')).status, 400);
  mock.on(DeleteObjectCommand).rejects(new Error('nope'));
  assert.equal((await call('DELETE', '/api/buckets/b/objects?key=k')).status, 500);
});

test('POST /api/sync: 200, 400, 500', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'srv-'));
  await writeFile(join(dir, 'a.txt'), 'a');
  mock.on(ListObjectsV2Command).resolves({});
  mock.on(PutObjectCommand).resolves({});
  assert.deepEqual(await call('POST', '/api/sync', { dir, bucket: 'b', prefix: 'p' }), {
    status: 200,
    json: { uploaded: 1, skipped: 0 },
  });
  assert.equal((await call('POST', '/api/sync', { bucket: 'b' })).status, 400);
  assert.equal((await call('POST', '/api/sync', { dir })).status, 400);
  const missing = await call('POST', '/api/sync', { dir: join(dir, 'gone'), bucket: 'b' });
  assert.equal(missing.status, 500);
});
