# 01-s3

## Goal

Create and delete a private S3 bucket with Terraform, and know the CLI equivalent.

## What it builds

- `aws_s3_bucket` — one bucket named `aws-practice-s3-bucket-<region>-<5 random letters>`, `force_destroy = true`
- `aws_s3_bucket_public_access_block` — all four public-access blocks on

## Cost

Free. An empty bucket costs nothing; S3 Free Tier covers small experiments (5 GB, 2,000 PUT, 20,000 GET per month for the first 6 months / Free Plan credits).

## CLI first (intuition)

```bash
B=aws-practice-s3-bucket-cli-$RANDOM
aws s3api create-bucket --bucket "$B" --region eu-north-1 \
  --create-bucket-configuration LocationConstraint=eu-north-1
aws s3api put-public-access-block --bucket "$B" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3 ls
aws s3 rb "s3://$B" --force     # removes objects, then the bucket
```

Note the `LocationConstraint` — required for every region except `us-east-1`.

## Run it (Terraform)

```bash
./scripts/whoami.sh              # from repo root; confirm account 395931907369
cd labs/01-s3/iac/terraform
terraform init
terraform plan
terraform apply
aws s3 ls | grep aws-practice-s3-bucket
```

## Tear it down

```bash
cd labs/01-s3/iac/terraform
terraform destroy
cd ../../.. && ./scripts/sweep.sh   # confirm nothing lingers
```

## What I learned

<!-- Fill in after. Reusable facts belong in ../../notes/s3.md. -->
