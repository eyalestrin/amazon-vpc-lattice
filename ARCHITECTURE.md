# AWS VPC Lattice Cross-Account Architecture

## Architecture Flow Diagram

```
┌─────────────────┐    HTTPS     ┌─────────────────────────────────────────────────────────┐
│                 │ ──────────► │                    AWS Account 1                        │
│   Web Browser   │              │  ┌─────────────────────────────────────────────────────┐ │
│                 │              │  │              Lambda Function                       │ │
└─────────────────┘              │  │  ┌─────────────────────────────────────────────┐   │ │
                                 │  │  │  • Function URL (Public Internet)          │   │ │
                                 │  │  │  • HTML Form for Transaction ID Input      │   │ │
                                 │  │  │  • Input Validation (1-999999)             │   │ │
                                 │  │  │  • JSON API Support                        │   │ │
                                 │  │  └─────────────────────────────────────────────┘   │ │
                                 │  │                        │                           │ │
                                 │  │                        │ Secrets Manager API       │ │
                                 │  │                        ▼                           │ │
                                 │  │  ┌─────────────────────────────────────────────┐   │ │
                                 │  │  │         AWS Secrets Manager                │   │ │
                                 │  │  │  • Cross-Account Secret Access             │   │ │
                                 │  │  │  • RDS Credentials Retrieval               │   │ │
                                 │  │  └─────────────────────────────────────────────┘   │ │
                                 │  │                        │                           │ │
                                 │  │                        │ Database Connection       │ │
                                 │  │                        ▼                           │ │
                                 │  │  ┌─────────────────────────────────────────────┐   │ │
                                 │  │  │            VPC (10.1.0.0/16)               │   │ │
                                 │  │  │  ┌─────────────────────────────────────┐   │   │ │
                                 │  │  │  │      VPC Lattice Association       │   │   │ │
                                 │  │  │  │   • Service Network Client         │   │   │ │
                                 │  │  │  │   • Private Connectivity           │   │   │ │
                                 │  │  │  └─────────────────────────────────────┘   │   │ │
                                 │  │  └─────────────────────────────────────────────┘   │ │
                                 │  └─────────────────────────────────────────────────────┘ │
                                 └─────────────────────────────────────────────────────────┘
                                                          │
                                                          │ VPC Lattice
                                                          │ (Private Network)
                                                          │ No Internet Gateway
                                                          │ No NAT Gateway
                                                          │ No VPC Endpoints
                                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                AWS Account 2                                            │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                          VPC (10.2.0.0/16)                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐   │   │
│  │  │                    VPC Lattice Service                                 │   │   │
│  │  │  ┌─────────────────────────────────────────────────────────────────┐   │   │   │
│  │  │  │                  Target Group                                   │   │   │   │
│  │  │  │  • TCP Port 5432                                               │   │   │   │
│  │  │  │  • Health Checks                                               │   │   │   │
│  │  │  │  • Load Balancing                                              │   │   │   │
│  │  │  └─────────────────────────────────────────────────────────────────┘   │   │   │
│  │  │                                │                                       │   │   │
│  │  │                                ▼                                       │   │   │
│  │  │  ┌─────────────────────────────────────────────────────────────────┐   │   │   │
│  │  │  │                RDS PostgreSQL Database                         │   │   │   │
│  │  │  │  • Engine: PostgreSQL 15.4                                     │   │   │   │
│  │  │  │  • Instance: db.t3.micro                                       │   │   │   │
│  │  │  │  • Database: transactionsdb                                    │   │   │   │
│  │  │  │  • Table: transactions                                         │   │   │   │
│  │  │  │    - id (SERIAL PRIMARY KEY)                                   │   │   │   │
│  │  │  │    - customer_id (INTEGER)                                     │   │   │   │
│  │  │  │    - product_name (VARCHAR)                                    │   │   │   │
│  │  │  │    - amount (DECIMAL)                                          │   │   │   │
│  │  │  │    - transaction_date (TIMESTAMP)                              │   │   │   │
│  │  │  │    - created_at (TIMESTAMP)                                    │   │   │   │
│  │  │  │  • Private Subnets (No Internet Access)                       │   │   │   │
│  │  │  └─────────────────────────────────────────────────────────────────┘   │   │   │
│  │  └─────────────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                        AWS Secrets Manager                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐   │   │
│  │  │                    RDS Credentials Secret                              │   │   │
│  │  │  • Username: dbadmin                                               │   │   │
│  │  │  • Password: [encrypted]                                           │   │   │
│  │  │  • Host: RDS Endpoint                                              │   │   │
│  │  │  • Port: 5432                                                      │   │   │
│  │  │  • Database: transactionsdb                                        │   │   │
│  │  │  • Cross-Account Access Policy                                     │   │   │
│  │  └─────────────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    AWS Resource Access Manager (RAM)                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐   │   │
│  │  │                VPC Lattice Service Network Share                       │   │   │
│  │  │  • Cross-Account Resource Sharing                                     │   │   │
│  │  │  • Account 1 Principal Association                                    │   │   │
│  │  │  • Service Network Access                                             │   │   │
│  │  └─────────────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. User Request Flow
```
User Browser → Lambda Function URL → Lambda Function → Input Validation
```

### 2. Authentication Flow
```
Lambda Function → AWS Secrets Manager (Account 2) → Retrieve DB Credentials
```

### 3. Database Query Flow
```
Lambda Function → VPC Lattice Service Network → VPC Lattice Service → 
Target Group → RDS PostgreSQL → Query Execution → Response
```

### 4. Response Flow
```
RDS PostgreSQL → VPC Lattice → Lambda Function → HTML/JSON Response → User Browser
```

## Security Boundaries

### Network Security
- **Account 1**: Lambda in private subnet with internet gateway for Function URL
- **Account 2**: RDS in private subnets with NO internet access
- **VPC Lattice**: Encrypted private connectivity between accounts
- **No VPC Peering**: No direct VPC-to-VPC connections
- **No VPC Endpoints**: No additional AWS service endpoints required
- **No NAT Gateway**: No internet routing for database traffic

### Access Control
- **Cross-Account IAM**: Lambda role has Secrets Manager access to Account 2
- **Secret Policy**: Account 2 secret allows Account 1 Lambda role access
- **RAM Sharing**: VPC Lattice service network shared via Resource Access Manager
- **Database Security**: RDS accessible only via VPC Lattice from Account 1

### Data Protection
- **Encryption in Transit**: All VPC Lattice traffic encrypted
- **Encryption at Rest**: RDS storage encrypted
- **Secrets Management**: Database credentials never hardcoded
- **Input Validation**: Transaction ID validation prevents SQL injection

## Components Interaction

1. **Web Interface**: HTML form with JavaScript validation
2. **Lambda Function**: Python runtime with psycopg2 and boto3
3. **VPC Lattice**: Service mesh for cross-account connectivity
4. **Secrets Manager**: Secure credential storage and retrieval
5. **RDS PostgreSQL**: Transactional database with sample data
6. **RAM**: Cross-account resource sharing for VPC Lattice

## Scalability & Performance

- **Lambda**: Auto-scaling based on request volume
- **VPC Lattice**: Built-in load balancing and health checks
- **RDS**: Can be scaled vertically or to Multi-AZ for high availability
- **Connection Pooling**: Lambda manages database connections efficiently

## Monitoring Points

- **CloudWatch Logs**: Lambda function execution logs
- **VPC Lattice Metrics**: Request count, latency, error rates
- **RDS Metrics**: Database performance and connection metrics
- **Secrets Manager**: Access logs and rotation events