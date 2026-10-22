# S3 SDK lab (Node.js)

AWS SDK for JavaScript v3 versions of the CLI labs in `../../bash-scripts/`.

## Prerequisites
- Node.js 20+ and npm
- Credentials/region from the default provider chain (`default` profile or env vars).
  Check the account first: `./scripts/whoami.sh` (repo root) must show `395931907369`.

## Install
```
npm install
```

## CLI
```
node cli.js list-buckets
node cli.js create-bucket my-practice-bucket
node cli.js list-objects my-practice-bucket [prefix]
node cli.js put-object my-practice-bucket ./file.txt [key]
node cli.js sync ./some-dir my-practice-bucket [prefix]
node cli.js delete-object my-practice-bucket file.txt
node cli.js delete-bucket my-practice-bucket [--force]   # --force empties it first
```
Usage errors exit 1; SDK errors exit 2.

## Web page
```
npm start
```
Open http://localhost:3000 (binds to 127.0.0.1; set `PORT` to change). The sync box takes a
directory path on the machine running the server.

## Tests
`npm test` — SDK mocked, no AWS calls. Coverage: `node --test --experimental-test-coverage`.

## Teardown
Delete any bucket you create (`delete-bucket --force` empties it first). Nothing else is provisioned.
