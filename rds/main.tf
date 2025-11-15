terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
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

variable "account1_id" {
  description = "AWS Account 1 ID (Lambda)"
  type        = string
}

# Random password generation
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# VPC for RDS
resource "aws_vpc" "rds_vpc" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "rds-vpc"
  }
}

resource "aws_subnet" "rds_subnet_1" {
  vpc_id            = aws_vpc.rds_vpc.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "rds-subnet-1"
  }
}

resource "aws_subnet" "rds_subnet_2" {
  vpc_id            = aws_vpc.rds_vpc.id
  cidr_block        = "10.2.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "rds-subnet-2"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# RDS Subnet Group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.rds_subnet_1.id, aws_subnet.rds_subnet_2.id]

  tags = {
    Name = "rds-subnet-group"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name   = "rds-sg"
  vpc_id = aws_vpc.rds_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# AWS Secrets Manager for RDS credentials
resource "aws_secretsmanager_secret" "rds_credentials" {
  name        = "rds-postgres-credentials"
  description = "RDS PostgreSQL database credentials"
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = 5432
    dbname   = "transactionsdb"
  })
}

# Cross-account secret policy
resource "aws_secretsmanager_secret_policy" "rds_credentials_policy" {
  secret_arn = aws_secretsmanager_secret.rds_credentials.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account1_id}:root"
        }
        Action   = "secretsmanager:GetSecretValue"
        Resource = "*"
      }
    ]
  })
}

# RDS PostgreSQL
resource "aws_db_instance" "postgres" {
  identifier             = "postgres-transactions-db"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "transactionsdb"
  username               = "dbadmin"
  password               = random_password.db_password.result
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  skip_final_snapshot    = true

  tags = {
    Name = "postgres-transactions-db"
  }
}

# VPC Lattice Service Network
resource "aws_vpclattice_service_network" "main" {
  name = "cross-account-network"
}

# VPC Lattice Service Network VPC Association
resource "aws_vpclattice_service_network_vpc_association" "rds_vpc_assoc" {
  vpc_identifier             = aws_vpc.rds_vpc.id
  service_network_identifier = aws_vpclattice_service_network.main.id
}

# VPC Lattice Service
resource "aws_vpclattice_service" "rds_service" {
  name = "rds-postgres-service"
}



# Note: RDS will be accessed directly through VPC, not through VPC Lattice target group
# VPC Lattice provides the network connectivity between accounts



# Cross-account service network association
resource "aws_vpclattice_service_network_service_association" "cross_account" {
  service_identifier         = aws_vpclattice_service.rds_service.id
  service_network_identifier = aws_vpclattice_service_network.main.id
}

# Cross-account service network sharing
resource "aws_ram_resource_share" "lattice_share" {
  name                      = "vpc-lattice-cross-account-share"
  allow_external_principals = true

  tags = {
    Name = "vpc-lattice-share"
  }
}

resource "aws_ram_resource_association" "lattice_share_association" {
  resource_arn       = aws_vpclattice_service_network.main.arn
  resource_share_arn = aws_ram_resource_share.lattice_share.arn
}

resource "aws_ram_principal_association" "lattice_share_principal" {
  principal          = var.account1_id
  resource_share_arn = aws_ram_resource_share.lattice_share.arn
}

# Outputs
output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "secret_arn" {
  value = aws_secretsmanager_secret.rds_credentials.arn
}

output "lattice_service_network_arn" {
  value = aws_vpclattice_service_network.main.arn
}

output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}