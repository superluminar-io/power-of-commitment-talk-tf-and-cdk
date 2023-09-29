import { Stack, StackProps, aws_dynamodb as dynamodb, aws_lambda_nodejs as lambdaNodeJs } from 'aws-cdk-lib';
import { Construct } from 'constructs';

export class LambdaDynamoDbStack extends Stack {
  public jugScanTable: dynamodb.Table;

  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    this.jugScanTable = new dynamodb.Table(this, 'jug-scan-table', {
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
    });

    const scanTable = new lambdaNodeJs.NodejsFunction(this, 'scan-table', {
      environment: {
        TABLE_NAME: this.jugScanTable.tableName,
      },
    });

    const putItem = new lambdaNodeJs.NodejsFunction(this, 'put-item', {
      environment: {
        TABLE_NAME: this.jugScanTable.tableName,
      },
    });

    this.jugScanTable.grant(scanTable, 'dynamodb:Scan');
    this.jugScanTable.grant(putItem, 'dynamodb:PutItem');
  }
}
