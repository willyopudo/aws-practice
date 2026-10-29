# 01-s3 (CDK, TypeScript)

CDK counterpart to `../terraform/`: one stack, `S3LabStack`, with one private, encrypted,
disposable bucket. CloudFormation names it; the stack outputs it as `BucketName`.

**Cost:** free. `autoDeleteObjects` adds a tiny Lambda + IAM role (free tier). `cdk bootstrap`
creates a one-time `CDKToolkit` stack (an S3 assets bucket + IAM roles), also free at this size.

## Prerequisites
Node 20+, and the `default` profile resolving to the practice account in `eu-north-1`.

## Run it
```bash
./scripts/whoami.sh                       # from repo root; confirm account 395931907369
cd labs/01-s3/iac/cdk
npm ci && npm test                        # synth assertions, no AWS calls
npx cdk bootstrap                         # once per account/region
npx cdk deploy
```

## Tear it down
```bash
npx cdk destroy                           # empties and deletes the bucket
cd ../../../.. && ./scripts/sweep.sh      # confirm nothing lingers
```
