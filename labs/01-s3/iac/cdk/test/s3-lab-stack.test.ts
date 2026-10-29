import { App, Tags } from 'aws-cdk-lib';
import { Match, Template } from 'aws-cdk-lib/assertions';
import { S3LabStack } from '../lib/s3-lab-stack';

function synth(): Template {
  const app = new App();
  Tags.of(app).add('Project', 'aws-practice');
  Tags.of(app).add('Lab', '01-s3-cdk');
  return Template.fromStack(new S3LabStack(app, 'S3LabStack'));
}

describe('S3LabStack', () => {
  const template = synth();

  test('creates exactly one bucket', () => {
    template.resourceCountIs('AWS::S3::Bucket', 1);
  });

  test('blocks all public access', () => {
    template.hasResourceProperties('AWS::S3::Bucket', {
      PublicAccessBlockConfiguration: {
        BlockPublicAcls: true,
        BlockPublicPolicy: true,
        IgnorePublicAcls: true,
        RestrictPublicBuckets: true,
      },
    });
  });

  test('encrypts with S3-managed keys', () => {
    template.hasResourceProperties('AWS::S3::Bucket', {
      BucketEncryption: {
        ServerSideEncryptionConfiguration: [
          { ServerSideEncryptionByDefault: { SSEAlgorithm: 'AES256' } },
        ],
      },
    });
  });

  test('leaves versioning off and the name to CloudFormation', () => {
    const [bucket] = Object.values(template.findResources('AWS::S3::Bucket'));
    expect(bucket.Properties.VersioningConfiguration).toBeUndefined();
    expect(bucket.Properties.BucketName).toBeUndefined();
  });

  test('is deleted on stack destroy, objects included', () => {
    template.hasResource('AWS::S3::Bucket', {
      DeletionPolicy: 'Delete',
      UpdateReplacePolicy: 'Delete',
    });
    template.hasResourceProperties('Custom::S3AutoDeleteObjects', {
      BucketName: Match.anyValue(),
    });
  });

  test('tags the bucket with Project and Lab', () => {
    template.hasResourceProperties('AWS::S3::Bucket', {
      Tags: Match.arrayWith([
        { Key: 'Lab', Value: '01-s3-cdk' },
        { Key: 'Project', Value: 'aws-practice' },
      ]),
    });
  });

  test('outputs the bucket name', () => {
    template.hasOutput('BucketName', { Value: { Ref: Match.stringLikeRegexp('^Bucket') } });
  });
});
