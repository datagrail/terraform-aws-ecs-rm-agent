# Complete Example

This example demonstrates a **production-ready configuration** with all available options for the DataGrail RM Agent Terraform module.

## What's Included

This example showcases **all configuration options** including:

### ✅ High Availability
- Multiple task instances (`desired_count = 2`)
- Multi-AZ subnet deployment
- Deployment circuit breaker with automatic rollback

### ✅ Security
- VPC endpoint integration (optional)
- Restricted egress rules to specific CIDR blocks
- KMS encryption for CloudWatch logs (optional)
- Private subnet validation

### ✅ Monitoring & Observability
- CloudWatch alarms for CPU, memory, and task health
- SNS notifications for critical events
- Extended log retention
- EventBridge rules for task stopped events

### ✅ Storage & Performance
- S3 integration for result storage
- Redis support for job queuing (optional)
- Configurable CPU/memory allocation
- Job timeout configuration

### ✅ Operations
- Comprehensive resource tagging
- ECS managed tags
- Custom IAM policies support
- Flexible deployment strategies

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (vpc-XXXX)                       │
│  ┌────────────────┐                    ┌────────────────┐   │
│  │ Private Subnet │                    │ Private Subnet │   │
│  │   (AZ-1)       │                    │   (AZ-2)       │   │
│  │  ┌──────────┐  │                    │  ┌──────────┐  │   │
│  │  │ RM Agent │  │                    │  │ RM Agent │  │   │
│  │  │  Task 1  │  │                    │  │  Task 2  │  │   │
│  │  └────┬─────┘  │                    │  └────┬─────┘  │   │
│  └───────┼────────┘                    └───────┼────────┘   │
│          │                                     │            │
│          │            Security Group           │            │
│          └──────────────┬──────────────────────┘            │
│                         │                                   │
│                         │ Egress Rules:                     │
│                         │ • DataGrail API (172.31.0.0/16)   │
│                         │ • AWS Services (VPC Endpoints)    │
│                         │ • S3 (Prefix List)                │
│                         │ • Redis (optional)                │
└─────────────────────────┼───────────────────────────────────┘
                          │
                  ┌───────▼────────┐
                  │  External      │
                  │  Resources     │
                  │  • DataGrail   │
                  │  • S3          │
                  │  • Secrets Mgr │
                  │  • Redis       │
                  └────────────────┘
```

## Prerequisites

### 1. AWS Infrastructure

- **VPC with private subnets**
  - At least 2 private subnets in different AZs
  - NAT Gateway or VPC endpoints for AWS service access
  - Proper route tables configured

- **Network connectivity**
  - Egress to DataGrail API: `172.31.0.0/16:443`
  - Egress to AWS services (ECR, Secrets Manager, CloudWatch, S3)
  - Optionally: Redis endpoint

### 2. AWS Resources

- **S3 Bucket**
  - Bucket for storing RM agent results
  - Same bucket configured in DataGrail platform

- **Secrets in AWS Secrets Manager**
  - DataGrail platform API credentials
  - DataGrail image registry credentials

- **SNS Topic** (for CloudWatch alarms)
  - Topic for receiving alerts
  - Proper IAM policy to allow EventBridge publishing

- **KMS Key** (optional, for log encryption)
  - Key for CloudWatch log encryption
  - Proper key policy to allow CloudWatch Logs service

### 3. VPC Endpoints (Optional but Recommended)

For enhanced security and reduced NAT Gateway costs:

```hcl
# S3 - Gateway Endpoint (free)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.us-west-2.s3"
  route_table_ids = [aws_route_table.private.id]
}

# Secrets Manager - Interface Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-west-2.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# ECR API - Interface Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-west-2.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# ECR DKR - Interface Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-west-2.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# CloudWatch Logs - Interface Endpoint (optional)
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-west-2.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}
```

## Usage

1. **Copy the example and update values in `main.tf`:**
   ```bash
   cp -r examples/complete my-rm-agent
   cd my-rm-agent
   ```

2. **Edit `main.tf` and replace placeholder values:**
   - VPC and subnet IDs
   - DataGrail configuration
   - AWS resource ARNs
   - Tags and other settings

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Review the plan:**
   ```bash
   terraform plan
   ```

5. **Apply the configuration:**
   ```bash
   terraform apply
   ```

## Configuration Options Explained

### High Availability Settings

```hcl
desired_count                      = 2    # Run 2 tasks for redundancy
deployment_minimum_healthy_percent = 100  # Keep all tasks healthy during updates
deployment_maximum_percent         = 200  # Allow double capacity during deployments
enable_deployment_circuit_breaker  = true # Auto-rollback on failed deployments
```

### Security Best Practices

```hcl
# Use VPC endpoints instead of NAT Gateway
secrets_manager_vpc_endpoint_sg_id = "sg-xxxxx"
ecr_api_vpc_endpoint_sg_id        = "sg-yyyyy"
ecr_dkr_vpc_endpoint_sg_id        = "sg-zzzzz"

# Encrypt logs
cloudwatch_log_group_kms_key_id = "arn:aws:kms:region:account:key/id"

# Restrict egress to specific CIDRs
datagrail_api_cidr = "172.31.0.0/16"
```

### Monitoring Configuration

```hcl
# Enable alarms by providing SNS topic
alarm_sns_topic_arn = "arn:aws:sns:region:account:ops-alerts"

# Configure thresholds
alarm_cpu_threshold      = 80  # Alert at 80% CPU
alarm_memory_threshold   = 80  # Alert at 80% memory
alarm_evaluation_periods = 2   # Alert after 2 consecutive periods
```

## Cost Considerations

### Estimated Monthly Costs (us-west-2)

| Resource | Configuration | Monthly Cost |
|----------|--------------|--------------|
| **Fargate Tasks** | 2 tasks × 1024 CPU × 2048 MB × 24/7 | ~$88 |
| **NAT Gateway** | 1 NAT × data transfer | ~$32 + data |
| **VPC Endpoints** | 4 interface endpoints × 24/7 | ~$29 |
| **CloudWatch Logs** | 10 GB ingestion + storage | ~$5 |
| **S3 Storage** | Depends on usage | Variable |
| **CloudWatch Alarms** | 4 alarms | ~$2 |
| **Total (without VPC endpoints)** | | ~$127/month |
| **Total (with VPC endpoints)** | | ~$124/month |

**Note:** Using VPC endpoints eliminates NAT Gateway data transfer charges and can result in cost savings.

## Outputs

This example exports all useful module outputs:

- `cluster_arn` - For service discovery
- `service_name`, `service_arn` - For monitoring and scaling
- `security_group_id` - For configuring network access
- `task_role_arn` - For attaching additional IAM policies
- `cloudwatch_log_group_name` - For log subscriptions
- `egress_configuration` - For network troubleshooting
- `subnet_availability_zones` - For deployment verification
- `cloudwatch_alarms_enabled` - For monitoring status

## Validation

After deployment, verify:

1. **Tasks are running:**
   ```bash
   aws ecs describe-services --cluster <cluster-name> --services <service-name>
   ```

2. **Health checks passing:**
   ```bash
   aws ecs describe-tasks --cluster <cluster-name> --tasks <task-arn>
   ```

3. **Logs are flowing:**
   ```bash
   aws logs tail /aws/ecs/rm-agent-prod --follow
   ```

4. **Alarms are active:**
   ```bash
   aws cloudwatch describe-alarms --alarm-name-prefix rm-agent
   ```

5. **Network connectivity:**
   - Check CloudWatch logs for successful connections to DataGrail API
   - Verify S3 uploads (if configured)
   - Confirm Redis connectivity (if configured)

## Troubleshooting

### Tasks Won't Start

```bash
# Check task events
aws ecs describe-services --cluster <cluster> --services <service> \
  --query 'services[0].events[:5]'

# Check task stopped reason
aws ecs describe-tasks --cluster <cluster> --tasks <task-arn> \
  --query 'tasks[0].stoppedReason'
```

### Network Connectivity Issues

```bash
# Verify security group rules
aws ec2 describe-security-group-rules \
  --filters Name=group-id,Values=<sg-id>

# Check VPC endpoint connectivity
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids <vpce-id>
```

### Image Pull Errors

```bash
# Verify registry credentials
aws secretsmanager get-secret-value \
  --secret-id <registry-credentials-arn>

# Check ECR VPC endpoint (if using)
aws ec2 describe-vpc-endpoints \
  --filters Name=service-name,Values=com.amazonaws.*.ecr.dkr
```

## Next Steps

After successful deployment:

1. **Set up monitoring dashboard** in CloudWatch
2. **Configure log aggregation** (e.g., ship to SIEM)
3. **Set up auto-scaling** if needed
4. **Document runbooks** for common operations
5. **Test disaster recovery** procedures
6. **Review and optimize costs** after 1 month

## Support

For issues specific to:
- **This Terraform module**: Create an issue in the repository
- **DataGrail RM Agent**: Contact DataGrail support
- **AWS infrastructure**: Reference AWS documentation

## Related Examples

- [Minimum Example](../minimum/) - Basic configuration with only required variables
