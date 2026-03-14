# Complete Example

This example demonstrates a **production-ready configuration** with all available options for the DataGrail RM Agent Terraform module.

## What's Included

This example showcases **all configuration options** including:

- ✅ **High Availability**: Single task with multi-AZ subnet deployment and automatic failover
- ✅ **Security**: Egress-only architecture, optional KMS encryption for logs, private subnet validation
- ✅ **Monitoring**: CloudWatch alarms for CPU, memory, task health, and SNS notifications
- ✅ **Storage**: S3 integration for result storage
- ✅ **Operations**: Comprehensive tagging, custom IAM policies, flexible deployment strategies
- ✅ **Integration Credentials**: Support for database credentials via Secrets Manager/Parameter Store

## Usage

1. **Create a new directory for your RM Agent configuration:**
   ```bash
   mkdir rm-agent && cd rm-agent
   ```

2. **Create a `main.tf` referencing this example:**
   ```hcl
   module "datagrail_rm_agent" {
     source = "git::https://github.com/datagrail/terraform-aws-ecs-rm-agent.git"

     # Or use a specific version:
     # source = "git::https://github.com/datagrail/terraform-aws-ecs-rm-agent.git?ref=v1.0.0"

     # VPC Configuration
     vpc_id             = "vpc-xxxxx"
     private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

     # DataGrail Configuration
     rm_customer_domain               = "example.datagrail.io"
     rm_platform_credentials_location = "arn:aws:secretsmanager:region:account:secret:datagrail-platform-key"

     # Container Configuration
     agent_container_image                   = "contairium.datagrail.io/rm-agent:v1.0.2"
     rm_agent_image_registry_credentials_arn = "arn:aws:secretsmanager:region:account:secret:datagrail-registry-creds"

     # S3 Storage
     rm_storage_manager = {
       provider = "AWSS3"
       bucket   = "datagrail-rm-agent-results"
     }

     # Integration Credentials
     integration_credentials_arns = [
       # "arn:aws:secretsmanager:region:account:secret:mysql-db-credentials",
       # "arn:aws:ssm:region:account:parameter/postgres/connection",
     ]

     # CloudWatch Alarms
     alarm_sns_topic_arn      = "arn:aws:sns:region:account:ops-alerts"
     alarm_cpu_threshold      = 80
     alarm_memory_threshold   = 80
     alarm_evaluation_periods = 2

     # CloudWatch Logs
     cloudwatch_log_retention_in_days = 90
     cloudwatch_log_group_kms_key_id  = null # "arn:aws:kms:region:account:key/id"

     # Resource Tagging
     tags = {
       Environment = "production"
       Team        = "platform"
       Application = "datagrail-rm-agent"
     }
   }
   ```

3. **Review the [example configuration](./main.tf)** in this directory for a complete reference with all available options.

4. **Deploy:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Configuration Highlights

### Monitoring & Alarms

```hcl
# Enable alarms by providing SNS topic
alarm_sns_topic_arn      = "arn:aws:sns:region:account:ops-alerts"
alarm_cpu_threshold      = 80
alarm_memory_threshold   = 80
alarm_evaluation_periods = 2
```

### Integration Credentials

```hcl
# Grant task role access to database credentials
integration_credentials_arns = [
  "arn:aws:secretsmanager:region:account:secret:mysql-db-credentials",
  "arn:aws:ssm:region:account:parameter/postgres/connection"
]
```

### Log Encryption

```hcl
# Encrypt CloudWatch logs with KMS
cloudwatch_log_group_kms_key_id = "arn:aws:kms:region:account:key/id"
```

## Additional Documentation

For detailed information, see the main [README](../../README.md):

- [Prerequisites](../../README.md#prerequisites)
- [Architecture](../../README.md#architecture)
- [AWS Infrastructure Requirements](../../README.md#aws-infrastructure-requirements)
- [VPC Endpoints](../../README.md#vpc-endpoints-recommended)
- [Cost Considerations](../../README.md#cost-considerations)
- [Monitoring and Validation](../../README.md#monitoring-and-validation)
- [Troubleshooting](../../README.md#troubleshooting)

## Outputs

This example exports all module outputs for easy reference:

- `cluster_arn`, `cluster_name` - ECS cluster information
- `service_name`, `service_arn` - ECS service details
- `security_group_id` - For configuring network access
- `task_role_arn`, `task_execution_role_arn` - For IAM policy management
- `cloudwatch_log_group_name` - For log subscriptions

## Related Examples

- [Minimum Example](../minimum/) - Basic configuration with only required variables
