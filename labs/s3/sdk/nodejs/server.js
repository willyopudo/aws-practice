import { createServer as createHttpServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { S3Client } from '@aws-sdk/client-s3';
import * as s3 from './s3.js';

const INDEX = fileURLToPath(new URL('./public/index.html', import.meta.url));

class BadRequest extends Error {}

const need = (value, what) => {
  if (typeof value !== 'string' || !value) throw new BadRequest(`Missing or invalid ${what}`);
  return value;
};

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  return Buffer.concat(chunks);
}

async function readJson(req) {
  try {
    return JSON.parse((await readBody(req)).toString() || '{}');
  } catch {
    throw new BadRequest('Invalid JSON body');
  }
}

async function route(client, req, url) {
  const { pathname, searchParams } = url;
  const m = pathname.match(/^\/api\/buckets(?:\/([^/]+)(\/objects)?)?$/);
  let bucket;
  try {
    bucket = m?.[1] && decodeURIComponent(m[1]);
  } catch {
    throw new BadRequest('Invalid bucket name encoding');
  }
  const method = req.method;

  if (m && !m[1]) {
    if (method === 'GET') return { buckets: await s3.listBuckets(client) };
    if (method === 'POST') return s3.createBucket(client, need((await readJson(req)).name, 'name'));
  } else if (m && !m[2]) {
    if (method === 'DELETE') return s3.deleteBucket(client, bucket);
  } else if (m) {
    if (method === 'GET') return { objects: await s3.listObjects(client, bucket, searchParams.get('prefix') ?? undefined) };
    if (method === 'PUT') {
      const key = need(searchParams.get('key'), 'key');
      return s3.putObject(client, bucket, key, await readBody(req));
    }
    if (method === 'DELETE') return s3.deleteObject(client, bucket, need(searchParams.get('key'), 'key'));
  } else if (pathname === '/api/sync' && method === 'POST') {
    const body = await readJson(req);
    return s3.syncDir(client, need(body.dir, 'dir'), need(body.bucket, 'bucket'), body.prefix || '');
  }
  return undefined;
}

export function createServer(client) {
  return createHttpServer(async (req, res) => {
    const send = (status, body, type = 'application/json') => {
      res.writeHead(status, { 'Content-Type': type });
      res.end(typeof body === 'string' ? body : JSON.stringify(body));
    };
    try {
      const url = new URL(req.url, 'http://localhost');
      if (req.method === 'GET' && url.pathname === '/') {
        return send(200, await readFile(INDEX, 'utf8'), 'text/html; charset=utf-8');
      }
      if (!url.pathname.startsWith('/api/')) return send(404, { error: 'Not found' });
      const result = await route(client, req, url);
      if (result === undefined) return send(404, { error: 'Not found' });
      return send(200, result);
    } catch (e) {
      return send(e instanceof BadRequest ? 400 : 500, { error: e.message });
    }
  });
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const port = Number(process.env.PORT) || 3000;
  createServer(new S3Client({})).listen(port, '127.0.0.1', () => {
    console.log(`S3 lab on http://127.0.0.1:${port}`);
  });
}
