terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account2_id" {
  description = "AWS Account 2 ID (RDS)"
  type        = string
}

variable "rds_secret_arn" {
  description = "ARN of RDS credentials secret in Account 2"
  type        = string
}

variable "lattice_service_network_arn" {
  description = "VPC Lattice Service Network ARN from Account 2"
  type        = string
}

# VPC for Lambda
resource "aws_vpc" "lambda_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "lambda-vpc"
  }
}

resource "aws_subnet" "lambda_subnet" {
  vpc_id     = aws_vpc.lambda_vpc.id
  cidr_block = "10.1.1.0/24"

  tags = {
    Name = "lambda-subnet"
  }
}

resource "aws_internet_gateway" "lambda_igw" {
  vpc_id = aws_vpc.lambda_vpc.id

  tags = {
    Name = "lambda-igw"
  }
}

resource "aws_route_table" "lambda_rt" {
  vpc_id = aws_vpc.lambda_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lambda_igw.id
  }

  tags = {
    Name = "lambda-rt"
  }
}

resource "aws_route_table_association" "lambda_rta" {
  subnet_id      = aws_subnet.lambda_subnet.id
  route_table_id = aws_route_table.lambda_rt.id
}

# VPC Lattice Service Network Association
resource "aws_vpclattice_service_network_vpc_association" "lambda_vpc_assoc" {
  vpc_identifier             = aws_vpc.lambda_vpc.id
  service_network_identifier = var.lattice_service_network_arn
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "lambda-vpc-lattice-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-vpc-lattice-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "vpc-lattice:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.rds_secret_arn
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "query_function" {
  filename         = "lambda_function.zip"
  function_name    = "query-transactions"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  vpc_config {
    subnet_ids         = [aws_subnet.lambda_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      RDS_SECRET_ARN = var.rds_secret_arn
      AWS_REGION     = var.aws_region
    }
  }

  depends_on = [data.archive_file.lambda_zip]
}

# Lambda Function URL
resource "aws_lambda_function_url" "query_function_url" {
  function_name      = aws_lambda_function.query_function.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["GET", "POST"]
    allow_headers     = ["date", "keep-alive", "content-type"]
    expose_headers    = ["date", "keep-alive"]
    max_age          = 86400
  }
}

# Security Group for Lambda
resource "aws_security_group" "lambda_sg" {
  name   = "lambda-sg"
  vpc_id = aws_vpc.lambda_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lambda-sg"
  }
}

# Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

# Outputs
output "lambda_function_url" {
  value = aws_lambda_function_url.query_function_url.function_url
}

output "vpc_id" {
  value = aws_vpc.lambda_vpc.id
}