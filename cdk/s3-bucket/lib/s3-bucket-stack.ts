import * as path from "path";
import {
  CfnOutput,
  RemovalPolicy,
  Stack,
  StackProps,
  aws_cloudfront as cloudfront,
  aws_cloudfront_origins as origins,
  aws_s3 as s3,
  aws_s3_deployment as s3deploy
} from "aws-cdk-lib";
import { Construct } from "constructs";


export class S3BucketStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const bucket = new s3.Bucket(this, "StaticHosting", {
      removalPolicy: RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
    });

    const distribution = new cloudfront.Distribution(
      this,
      "StaticHostingDistribution",
      {
        defaultBehavior: { origin: new origins.S3Origin(bucket) },
        defaultRootObject: "index.html",
      }
    );

    new s3deploy.BucketDeployment(this, "StaticHostingDeployment", {
      destinationBucket: bucket,
      sources: [s3deploy.Source.asset(path.resolve(__dirname, "./dist"))],
      distribution,
    });

    new CfnOutput(this, "DistributionURL", {
      value: `https://${distribution.distributionDomainName}`,
    });
  }
}