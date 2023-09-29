import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocument } from '@aws-sdk/lib-dynamodb';

export const handler = async () => {
  const DB = DynamoDBDocument.from(new DynamoDBClient({}));

  await DB.put({
    Item: {
      id: "#jug#2023-09-29",
      sessionTitle: "the - power - of - commitment",
      speaker1: "Verena Traub",
      speaker2: "Nora Schöner",
    },
    TableName: process.env.TABLE_NAME!,
  });

  return {
    statusCode: 201,
  };
};