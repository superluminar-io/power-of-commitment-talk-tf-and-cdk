#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { S3BucketStack } from '../lib/s3-bucket-stack';

const app = new cdk.App();

new S3BucketStack(app, 'S3BucketStack', {

  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },

});

app.synth();

/*--------------------------------------------------------------
  * maintained by vtrHH
  * for educational purpose only, no production readyness garantued
--------------------------------------------------------------*/