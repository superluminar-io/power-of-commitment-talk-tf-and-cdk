import boto3
import os


def lambda_handler(event, context):
    dynamodb = boto3.client('dynamodb')
    table_name = os.environ['TABLE_NAME']

    response = dynamodb.scan(TableName=table_name)

    items = response.get('Items', [])
    for item in items:
        print(item)

    return {
        'statusCode': 200,
        'body': 'Table scan completed.'
    }
