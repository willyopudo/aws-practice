import { readdir, readFile, stat } from 'node:fs/promises';
import { join, relative, sep } from 'node:path';
import {
  AbortMultipartUploadCommand,
  CreateBucketCommand,
  DeleteBucketCommand,
  DeleteObjectsCommand,
  DeleteObjectCommand,
  ListBucketsCommand,
  ListMultipartUploadsCommand,
  ListObjectVersionsCommand,
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

// Every version and delete marker in the bucket, following pagination.
async function listVersions(client, bucket) {
  const items = [];
  let keyMarker;
  let versionIdMarker;
  do {
    const res = await client.send(
      new ListObjectVersionsCommand({ Bucket: bucket, KeyMarker: keyMarker, VersionIdMarker: versionIdMarker }),
    );
    for (const v of [...(res.Versions ?? []), ...(res.DeleteMarkers ?? [])]) {
      items.push({ Key: v.Key, VersionId: v.VersionId });
    }
    keyMarker = res.IsTruncated ? res.NextKeyMarker : undefined;
    versionIdMarker = res.IsTruncated ? res.NextVersionIdMarker : undefined;
  } while (keyMarker || versionIdMarker);
  return items;
}

async function abortUploads(client, bucket) {
  let aborted = 0;
  let keyMarker;
  let uploadIdMarker;
  do {
    const res = await client.send(
      new ListMultipartUploadsCommand({ Bucket: bucket, KeyMarker: keyMarker, UploadIdMarker: uploadIdMarker }),
    );
    for (const u of res.Uploads ?? []) {
      await client.send(new AbortMultipartUploadCommand({ Bucket: bucket, Key: u.Key, UploadId: u.UploadId }));
      aborted++;
    }
    keyMarker = res.IsTruncated ? res.NextKeyMarker : undefined;
    uploadIdMarker = res.IsTruncated ? res.NextUploadIdMarker : undefined;
  } while (keyMarker || uploadIdMarker);
  return aborted;
}

// With { force: true }, empties the bucket first: all object versions, delete markers and
// incomplete multipart uploads. Without versioning, ListObjectVersions returns the plain objects.
export async function deleteBucket(client, bucket, { force = false } = {}) {
  let deleted = 0;
  let aborted = 0;
  if (force) {
    const items = await listVersions(client, bucket);
    for (let i = 0; i < items.length; i += 1000) {
      const batch = items.slice(i, i + 1000);
      const res = await client.send(
        new DeleteObjectsCommand({ Bucket: bucket, Delete: { Objects: batch, Quiet: true } }),
      );
      if (res.Errors?.length) throw new Error(`Failed to delete ${res.Errors[0].Key}: ${res.Errors[0].Message}`);
      deleted += batch.length;
    }
    aborted = await abortUploads(client, bucket);
  }
  await client.send(new DeleteBucketCommand({ Bucket: bucket }));
  return force ? { bucket, deleted, abortedUploads: aborted } : { bucket };
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
