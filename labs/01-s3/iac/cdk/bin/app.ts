#!/usr/bin/env node
import { App, Tags } from 'aws-cdk-lib';
import { S3LabStack } from '../lib/s3-lab-stack';

const app = new App();

// Every taggable resource gets these. scripts/sweep.sh relies on them to find orphans.
Tags.of(app).add('Project', 'aws-practice');
Tags.of(app).add('Lab', '01-s3-cdk');

new S3LabStack(app, 'S3LabStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
});
