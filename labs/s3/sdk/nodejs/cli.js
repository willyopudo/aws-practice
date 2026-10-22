import { readFile } from 'node:fs/promises';
import { basename } from 'node:path';
import { pathToFileURL } from 'node:url';
import { S3Client } from '@aws-sdk/client-s3';
import * as s3 from './s3.js';

const USAGE = `Usage: node cli.js <command> [args]
  list-buckets
  create-bucket <bucket>
  delete-bucket <bucket> [--force]   (--force empties the bucket first)
  list-objects <bucket> [prefix]
  put-object <bucket> <file> [key]
  sync <dir> <bucket> [prefix]
  delete-object <bucket> <key>`;

// name -> [min args, max args, handler(client, args)]
const COMMANDS = {
  'list-buckets': [0, 0, (c) => s3.listBuckets(c)],
  'create-bucket': [1, 1, (c, [b]) => s3.createBucket(c, b)],
  'delete-bucket': [1, 1, (c, [b], force) => s3.deleteBucket(c, b, { force })],
  'list-objects': [1, 2, (c, [b, p]) => s3.listObjects(c, b, p)],
  'put-object': [2, 3, async (c, [b, f, k]) => s3.putObject(c, b, k ?? basename(f), await readFile(f))],
  sync: [2, 3, (c, [d, b, p]) => s3.syncDir(c, d, b, p)],
  'delete-object': [2, 2, (c, [b, k]) => s3.deleteObject(c, b, k)],
};

export async function run(argv, client = new S3Client({}), out = console.log, err = console.error) {
  const [name, ...rest] = argv;
  const force = name === 'delete-bucket' && rest.includes('--force');
  const args = force ? rest.filter((a) => a !== '--force') : rest;
  const cmd = COMMANDS[name];
  if (!cmd || args.length < cmd[0] || args.length > cmd[1]) {
    err(USAGE);
    return 1;
  }
  try {
    out(JSON.stringify(await cmd[2](client, args, force), null, 2));
    return 0;
  } catch (e) {
    err(e.message);
    return 2;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = await run(process.argv.slice(2));
}
