---
id: 002-s3-sdk-nodejs
coverage_min: 70
sonar: true
max_iterations: 5
max_turns: 60
max_budget_usd: 3
model: sonnet
---

# S3 SDK lab (Node.js)

## Objective
Add a small Node.js lab in `labs/s3/sdk/nodejs/` that uses the AWS SDK for JavaScript v3
(`@aws-sdk/client-s3`) to manage S3 buckets and objects. Keep it simple: a thin module of
functions, a tiny CLI, and a local web page to try the operations without typing commands.
Mirror the operations already covered by the CLI labs in `labs/s3/bash-scripts/`.

## Acceptance criteria
- [ ] `s3.js` exports one function per operation, each taking a client as its first argument:
      `listBuckets`, `createBucket`, `deleteBucket`, `listObjects`, `putObject`, `syncDir`, `deleteObject`.
- [ ] `cli.js` dispatches subcommands to those functions and prints results to stdout:
      `list-buckets`, `create-bucket <bucket>`, `delete-bucket <bucket>`, `list-objects <bucket> [prefix]`,
      `put-object <bucket> <file> [key]`, `sync <dir> <bucket> [prefix]`, `delete-object <bucket> <key>`.
- [ ] `server.js` uses only Node's built-in `http` (no Express). It exports `createServer(client)` so tests can inject a mock client, and starts listening only when run directly (`npm start`).
      It binds to `127.0.0.1`, port from `PORT` (default 3000), and serves `public/index.html` at `/`.
- [ ] `server.js` exposes JSON endpoints that call the `s3.js` functions:
      `GET /api/buckets`, `POST /api/buckets` (body `{name}`), `DELETE /api/buckets/:bucket`,
      `GET /api/buckets/:bucket/objects?prefix=`, `PUT /api/buckets/:bucket/objects?key=` (raw request body is the file content),
      `DELETE /api/buckets/:bucket/objects?key=`, `POST /api/sync` (body `{dir, bucket, prefix}`, `dir` is a path on the machine running the server).
      Success returns 200 with JSON; missing or invalid input returns 400 `{error}`; an SDK error returns 500 `{error}` with the error message.
- [ ] `public/index.html` is a single file with inline vanilla JS and CSS (no framework, no build step, no CDN). It lets you:
      list buckets, create a bucket, delete a bucket (with a `confirm()` prompt), pick a bucket to list its objects (with optional prefix),
      upload a file via a file input, delete an object, and run a sync from a directory path.
      Results and errors show in a single output area on the page.
- [ ] `createBucket` handles the `us-east-1` case (no `LocationConstraint`) and every other region (with `LocationConstraint`).
- [ ] `listObjects` follows pagination (`ContinuationToken`) so it returns all keys, not just the first 1000.
- [ ] `syncDir` is one-way, local to bucket: it uploads files that are missing in the bucket or differ in size, skips the rest, and returns the counts of uploaded and skipped files. It does not delete anything.
- [ ] CLI: wrong argument count prints a usage message to stderr and exits 1; an SDK error prints the error message to stderr and exits 2.
- [ ] Region and credentials come from the default SDK provider chain (env, profile). Nothing is hard-coded and nothing credential-related is sent to or stored in the browser.
- [ ] `package.json` has `"type": "module"`, a single dependency (`@aws-sdk/client-s3`), a single dev dependency (`aws-sdk-client-mock`), and scripts `test` (built-in `node --test`) and `start` (`node server.js`).
- [ ] Tests (`*.test.js`) mock the SDK client with `aws-sdk-client-mock`: no network, no real AWS calls.
      Each `s3.js` function is covered for the happy path and an SDK failure; the CLI is covered for the usage error;
      each server endpoint is covered for success, a 400 and a 500 (call `createServer(mockClient)` on an ephemeral port).
      `index.html` is not unit-tested.
- [ ] `README.md` in the lab dir: prerequisites, install, one example command per CLI subcommand, and how to start the web page (`npm start`, open `http://localhost:3000`). Under 50 lines.
- [ ] Line coverage ≥ 80% for the lab's JS (`node --test --experimental-test-coverage`), with no new entries in `tests/coverage-exclude.txt`.
- [ ] Quality gate passes (`scripts/quality-gate.sh`).

## Scope
- `labs/s3/sdk/nodejs/` only (source, `public/`, tests, `package.json`, `README.md`).

## Out of scope
- No real AWS calls in tests. No TypeScript, no build step, no frontend framework, no CSS library, no extra CLI frameworks (use `process.argv`).
- No auth, no multipart form parsing, no drag-and-drop, no pagination UI, no object download or preview.
- No multipart upload, presigned URLs, versioning, or bucket policies.
- No changes to `scripts/`, `tests/helpers/`, `labs/s3/bash-scripts/`, or the workflow tooling.
