# AWS VPC Lattice Cross-Account Transaction Store

This project demonstrates a secure cross-account architecture using AWS VPC Lattice, where a Lambda function in Account 1 connects privately to an RDS PostgreSQL database in Account 2 for transaction data management.

## Architecture Overview

- **Account 1 (Lambda)**: Lambda function with public Function URL, VPC Lattice Service Network association
- **Account 2 (RDS)**: RDS PostgreSQL database, VPC Lattice Service, AWS Secrets Manager
- **Connection**: Secure private communication through VPC Lattice across accounts (no VPC endpoints or NAT gateways)
- **Security**: Database credentials managed via AWS Secrets Manager with cross-account access

## Prerequisites

- Two AWS accounts with appropriate permissions
- AWS CLI configured with cross-account access
- Terraform installed (available in AWS CloudShell)
- Access to AWS CloudShell
- PostgreSQL client (psql) for data import

## Required Permissions

### Account 1 (Lambda)
- Lambda, VPC, VPC Lattice, IAM permissions
- Cross-account Secrets Manager access
- Cross-account VPC Lattice service network association

### Account 2 (RDS)
- RDS, VPC, VPC Lattice permissions
- AWS Secrets Manager permissions
- AWS RAM (Resource Access Manager) permissions
- Cross-account VPC Lattice service association

## Deployment Steps

### 1. Clone Repository

```bash
git clone https://github.com/eyalestrin/amazon-vpc-lattice.git
cd amazon-vpc-lattice
```

### 2. Deploy RDS Account (Account 2) First

Get your AWS Account IDs:
```bash
# Get current account ID (Account 2 - RDS)
AWS_ACCOUNT_2=$(aws sts get-caller-identity --query Account --output text)
echo "Account 2 (RDS): $AWS_ACCOUNT_2"

# You'll need Account 1 ID manually (the Lambda account)
echo "Enter Account 1 ID (Lambda account):"
read AWS_ACCOUNT_1
```

Create and configure terraform.tfvars:
```bash
cd rds
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
cat > terraform.tfvars <<EOF
aws_region  = "us-east-1"
account1_id = "$AWS_ACCOUNT_1"
db_password = "YourSecurePassword123!"
EOF
```

Or manually edit `terraform.tfvars`:
```hcl
aws_region  = "us-east-1"
account1_id = "123456789012"  # Replace with your Account 1 ID
db_password = "YourSecurePassword123!"  # Replace with secure password
```

Deploy RDS infrastructure:
```bash
terraform init
terraform plan
terraform apply -auto-approve
```

Save the outputs:
```bash
terraform output secret_arn
terraform output lattice_service_network_arn
terraform output rds_endpoint
```

### 3. Import Transaction Data

```bash
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
psql -h $RDS_ENDPOINT -U dbadmin -d transactionsdb -f transactions_data.sql
```

When prompted, enter the password you set in `terraform.tfvars`.

### 4. Deploy Lambda Account (Account 1)

Get values from RDS deployment:
```bash
# Get Account 2 ID
AWS_ACCOUNT_2=$(aws sts get-caller-identity --query Account --output text)
echo "Account 2 (RDS): $AWS_ACCOUNT_2"

# Get RDS outputs (run from rds directory)
SECRET_ARN=$(cd ../rds && terraform output -raw secret_arn)
LATTICE_ARN=$(cd ../rds && terraform output -raw lattice_service_network_arn)

echo "Secret ARN: $SECRET_ARN"
echo "Lattice Network ARN: $LATTICE_ARN"
```

Create and configure terraform.tfvars:
```bash
cd lambda
cp terraform.tfvars.example terraform.tfvars

# Auto-generate terraform.tfvars with values
cat > terraform.tfvars <<EOF
aws_region                   = "us-east-1"
account2_id                  = "$AWS_ACCOUNT_2"
rds_secret_arn              = "$SECRET_ARN"
lattice_service_network_arn = "$LATTICE_ARN"
EOF
```

Or manually edit `terraform.tfvars`:
```hcl
aws_region                   = "us-east-1"
account2_id                  = "123456789013"  # Replace with your Account 2 ID
rds_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789013:secret:rds-postgres-credentials-XXXXXX"  # From step 2 output
lattice_service_network_arn = "arn:aws:vpc-lattice:us-east-1:123456789013:servicenetwork/sn-XXXXXXXXX"  # From step 2 output
```

Create Lambda package and deploy:
```bash
mkdir lambda_package
cp lambda_function.py lambda_package/
pip install -r requirements.txt -t lambda_package/
cd lambda_package && zip -r ../lambda_function.zip . && cd ..
rm -rf lambda_package
terraform init
terraform plan
terraform apply -auto-approve
```

Get your Lambda Function URL:
```bash
terraform output lambda_function_url
```

### 5. Automated Deployment (Alternative)

```bash
chmod +x deploy.sh
./deploy.sh
```

## Usage

### Web Interface (Browser)

1. Open the Lambda Function URL in your browser
2. Enter a Transaction ID (1-15 for sample data)
3. Click "Lookup Transaction" to retrieve details
4. View transaction information with secure cross-account database access

**Input Validation:**
- Transaction ID must be a positive integer (1-999999)
- Based on SQL SERIAL PRIMARY KEY constraints
- Real-time validation with user-friendly error messages

### API Usage (Programmatic)

#### Get All Transactions
```bash
FUNCTION_URL=$(cd lambda && terraform output -raw lambda_function_url)
curl -X GET "$FUNCTION_URL"
```

#### Get Specific Transaction
```bash
curl -X GET "${FUNCTION_URL}?id=1"
```

#### Create New Transaction
```bash
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": 1001,
    "product_name": "New Product",
    "amount": 99.99,
    "transaction_date": "2024-01-22T10:00:00"
  }'
```

## Response Format

### Transaction Response
```json
{
  "id": 1,
  "customer_id": 1001,
  "product_name": "Laptop Computer",
  "amount": 1299.99,
  "transaction_date": "2024-01-15T10:30:00",
  "created_at": "2024-01-15T10:30:00"
}
```

### Error Response
```json
{
  "error": "Transaction not found"
}
```

## Security Features

- **Private Communication**: VPC Lattice ensures private connectivity between accounts (no VPC endpoints or NAT gateways)
- **No Internet Exposure**: RDS database is not accessible from the internet
- **Secrets Management**: Database credentials stored in AWS Secrets Manager with cross-account access
- **Secure Authentication**: Cross-account IAM roles and policies
- **Network Isolation**: Separate VPCs with controlled access
- **Resource Sharing**: AWS RAM for secure cross-account VPC Lattice sharing

## Monitoring and Troubleshooting

### CloudWatch Logs
- Lambda function logs: `/aws/lambda/query-transactions`
- VPC Lattice access logs (if enabled)

### Common Issues

1. **Cross-account permissions**: Ensure both accounts have proper VPC Lattice and Secrets Manager permissions
2. **Database connectivity**: Check security groups and VPC Lattice target group health
3. **Secrets Manager access**: Verify cross-account secret policy allows Lambda role access
4. **Lambda timeout**: Increase timeout if database operations are slow
5. **RAM sharing**: Ensure VPC Lattice service network is properly shared via AWS RAM

### Testing Connectivity

```bash
aws lambda invoke \
  --function-name query-transactions \
  --payload '{"requestContext":{"http":{"method":"GET"}}}' \
  response.json
cat response.json
```

### Verify Secrets Manager Access

```bash
SECRET_ARN=$(cd rds && terraform output -raw secret_arn)
aws secretsmanager get-secret-value --secret-id $SECRET_ARN
```

## Cleanup

Destroy resources in reverse order:

```bash
cd lambda
terraform destroy -auto-approve
cd ../rds
terraform destroy -auto-approve
```

## Cost Considerations

- **Lambda**: Pay per request and execution time
- **RDS**: db.t3.micro instance (~$13/month)
- **VPC Lattice**: Pay per processed GB and connection time
- **Data Transfer**: Cross-AZ charges may apply

## Architecture

For detailed architecture diagrams and data flow, see [ARCHITECTURE.md](ARCHITECTURE.md).

**High-Level Flow:**
```
Browser → Lambda Function URL → Lambda (Account 1) → VPC Lattice → RDS PostgreSQL (Account 2)
                                      ↓
                              AWS Secrets Manager (Account 2)
```

## File Structure

```
├── lambda/                           # Account 1 (Lambda) resources
│   ├── main.tf                      # Lambda Terraform configuration
│   ├── lambda_function.py           # Lambda function code with web interface
│   ├── requirements.txt             # Python dependencies
│   └── terraform.tfvars.example     # Lambda configuration template
├── rds/                             # Account 2 (RDS) resources
│   ├── main.tf                      # RDS Terraform configuration
│   ├── transactions_data.sql        # Sample transaction data
│   └── terraform.tfvars.example     # RDS configuration template
├── deploy.sh                        # Automated deployment script
├── push-to-git.sh                   # Script to push code to GitHub
├── ARCHITECTURE.md                  # Detailed architecture documentation
├── .gitignore                       # Git ignore file
└── README.md                        # This documentation
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Pushing to GitHub

### Using the Script (Recommended)
```bash
chmod +x push-to-git.sh
./push-to-git.sh
```

### Manual Push
```bash
git init
git add .
git commit -m "Initial commit: AWS VPC Lattice cross-account transaction store"
git remote add origin https://github.com/eyalestrin/amazon-vpc-lattice.git
git branch -M main
git push -u origin main
```

### Updating Repository
```bash
git add .
git commit -m "Update: Add web interface and architecture documentation"
git push origin main
```

## Support

For issues and questions:
- Check AWS VPC Lattice documentation
- Review CloudWatch logs
- Verify cross-account permissions
- Test network connectivity
- Review [ARCHITECTURE.md](ARCHITECTURE.md) for detailed flow diagrams