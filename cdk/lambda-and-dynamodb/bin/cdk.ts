#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { LambdaDynamoDbStack } from '../lib/lambda-dynamobd-stack';

const app = new cdk.App();

new LambdaDynamoDbStack(app, 'LambdaStack', {

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