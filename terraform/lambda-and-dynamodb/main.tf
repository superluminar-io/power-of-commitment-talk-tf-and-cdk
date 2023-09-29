/* ----------------------------------------------------------
  main.tf
  * maintained by @norchen
  * for educational purpose only, no production readiness guaranteed
------------------------------------------------------------*/

/* ----------------------------------------------------------
  set provider
------------------------------------------------------------*/
# the starting point to connect to AWS
provider "aws" {
  profile = "test"     # the profile you configured via AWS CLI
  region  = var.region # the region you want to deploy to

  # default tags to be added to every AWS ressource
  default_tags {
    tags = {
      Owner = "Wolkencode"
    }
  }
}

# configure terraform version and backend properties
terraform {
  required_providers {

    # sets version for AWS Terraform provider
    # https://github.com/hashicorp/terraform-provider-aws/blob/main/CHANGELOG.md
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # sets Terraform version
  required_version = ">= 1.1"

  # if applicable put your remote backend configuration here (e.g. S3 backend)
  # backend "s3" {...}
}

/* ----------------------------------------------------------
  set locals & variables
------------------------------------------------------------*/
variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

/* ----------------------------------------------------------
  set resources
------------------------------------------------------------*/

# dynamodb table
resource "aws_dynamodb_table" "jug_scan_table" {
  name           = "jug-scanning-table-example"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "jug_scan_table" {
  table_name = aws_dynamodb_table.jug_scan_table.name
  hash_key   = aws_dynamodb_table.jug_scan_table.hash_key

  item = <<ITEM
{
  "id": {"S": "#jug#2023-09-29"},
  "sessionTitle": {"S": "the-power-of-commitment"},
  "speaker1": {"S": "Verena Traub"},
  "speaker2": {"S": "Nora Schöner"},
}
ITEM
}

# lambda function
resource "aws_lambda_function" "jug_scan_table" {
  filename      = "${path.cwd}/lambda.zip"
  function_name = "jug_scan_table"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "jug_scan_table.lambda_handler"
  runtime       = "python3.8"
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "Policy for Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = [
        "dynamodb:Scan",
        "dynamodb:Query",
      ],
      Effect   = "Allow",
      Resource = aws_dynamodb_table.jug_scan_table.arn,
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_execution_role.name
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.cwd}/lambda_code"
  output_path = "${path.cwd}/lambda.zip"
}

output "lambda_function_arn" {
  value = aws_lambda_function.jug_scan_table.arn
}
