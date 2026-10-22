import { readdir, readFile, stat } from 'node:fs/promises';
import { join, relative, sep } from 'node:path';
import {
  CreateBucketCommand,
  DeleteBucketCommand,
  DeleteObjectCommand,
  ListBucketsCommand,
  ListObjectsV2Command,
  PutObjectCommand,
} from '@aws-sdk/client-s3';

export async function listBuckets(client) {
  const { Buckets = [] } = await client.send(new ListBucketsCommand({}));
  return Buckets.map((b) => b.Name);
}

export async function createBucket(client, bucket) {
  const region = await client.config.region();
  const input = { Bucket: bucket };
  if (region !== 'us-east-1') {
    input.CreateBucketConfiguration = { LocationConstraint: region };
  }
  await client.send(new CreateBucketCommand(input));
  return { bucket, region };
}

export async function deleteBucket(client, bucket) {
  await client.send(new DeleteBucketCommand({ Bucket: bucket }));
  return { bucket };
}

async function listAll(client, bucket, prefix) {
  const objects = [];
  let token;
  do {
    const res = await client.send(
      new ListObjectsV2Command({ Bucket: bucket, Prefix: prefix || undefined, ContinuationToken: token }),
    );
    objects.push(...(res.Contents ?? []));
    token = res.IsTruncated ? res.NextContinuationToken : undefined;
  } while (token);
  return objects;
}

export async function listObjects(client, bucket, prefix) {
  return (await listAll(client, bucket, prefix)).map((o) => o.Key);
}

export async function putObject(client, bucket, key, body) {
  await client.send(new PutObjectCommand({ Bucket: bucket, Key: key, Body: body }));
  return { bucket, key };
}

async function walk(dir) {
  const files = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) files.push(...(await walk(full)));
    else if (entry.isFile()) files.push(full);
  }
  return files;
}

// One-way, local -> bucket. Uploads files that are missing or differ in size; never deletes.
export async function syncDir(client, dir, bucket, prefix = '') {
  const base = prefix && !prefix.endsWith('/') ? `${prefix}/` : prefix;
  const remote = new Map((await listAll(client, bucket, base)).map((o) => [o.Key, o.Size]));
  let uploaded = 0;
  let skipped = 0;
  for (const file of await walk(dir)) {
    const key = base + relative(dir, file).split(sep).join('/');
    const { size } = await stat(file);
    if (remote.get(key) === size) {
      skipped++;
      continue;
    }
    await putObject(client, bucket, key, await readFile(file));
    uploaded++;
  }
  return { uploaded, skipped };
}

export async function deleteObject(client, bucket, key) {
  await client.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
  return { bucket, key };
}
