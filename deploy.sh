#!/bin/bash

# AWS VPC Lattice Cross-Account Deployment Script
# Run this from AWS CloudShell

set -e

echo "Starting VPC Lattice Cross-Account Deployment..."

# Check current directory
if [ ! -d "lambda" ] || [ ! -d "rds" ]; then
    echo "Error: lambda and rds directories not found!"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Deploy RDS Account (Account 2) first
echo "=== Deploying RDS Account (Account 2) ==="
cd rds

if [ ! -f "terraform.tfvars" ]; then
    echo "Error: rds/terraform.tfvars file not found!"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and update with your values"
    exit 1
fi

echo "Initializing Terraform for RDS account..."
terraform init

echo "Planning RDS deployment..."
terraform plan

echo "Applying RDS configuration..."
terraform apply -auto-approve

# Get outputs from RDS deployment
SECRET_ARN=$(terraform output -raw secret_arn)
LATTICE_NETWORK_ARN=$(terraform output -raw lattice_service_network_arn)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

echo "RDS deployment completed!"
echo "Secret ARN: $SECRET_ARN"
echo "Lattice Network ARN: $LATTICE_NETWORK_ARN"

# Import data into RDS
echo "Importing transaction data into RDS..."
echo "Please run the following command manually to import data:"
echo "psql -h $RDS_ENDPOINT -U dbadmin -d transactionsdb -f transactions_data.sql"

cd ..

# Deploy Lambda Account (Account 1)
echo "=== Deploying Lambda Account (Account 1) ==="
cd lambda

if [ ! -f "terraform.tfvars" ]; then
    echo "Creating terraform.tfvars from RDS outputs..."
    cp terraform.tfvars.example terraform.tfvars
    
    # Update terraform.tfvars with actual values
    sed -i "s|rds_secret_arn.*|rds_secret_arn = \"$SECRET_ARN\"|" terraform.tfvars
    sed -i "s|lattice_service_network_arn.*|lattice_service_network_arn = \"$LATTICE_NETWORK_ARN\"|" terraform.tfvars
    
    echo "Please update lambda/terraform.tfvars with your Account 2 ID and region"
    echo "Then run: cd lambda && terraform init && terraform apply"
    exit 0
fi

# Create Lambda deployment package
echo "Creating Lambda deployment package..."
mkdir -p lambda_package
cp lambda_function.py lambda_package/
pip install -r requirements.txt -t lambda_package/
cd lambda_package && zip -r ../lambda_function.zip . && cd ..
rm -rf lambda_package

echo "Initializing Terraform for Lambda account..."
terraform init

echo "Planning Lambda deployment..."
terraform plan

echo "Applying Lambda configuration..."
terraform apply -auto-approve

# Get Lambda function URL
FUNCTION_URL=$(terraform output -raw lambda_function_url)

echo "Lambda deployment completed!"
echo "Function URL: $FUNCTION_URL"

cd ..

echo "=== Deployment Summary ==="
echo "RDS Secret ARN: $SECRET_ARN"
echo "VPC Lattice Network ARN: $LATTICE_NETWORK_ARN"
echo "Lambda Function URL: $FUNCTION_URL"

# Test the deployment
echo "=== Testing the deployment ==="
echo "Testing GET request:"
curl -X GET "$FUNCTION_URL"

echo -e "\n\nTesting POST request:"
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 9999, "product_name": "Test Product", "amount": 99.99, "transaction_date": "2024-01-22T10:00:00"}'

echo -e "\n\nDeployment and testing completed!"