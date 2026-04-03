# Minimum Example

This example demonstrates the **minimum required configuration** to deploy the DataGrail RM Agent using this Terraform module.

## What's Included

This example only sets the **required variables**:

- ✅ VPC and private subnet configuration
- ✅ DataGrail customer domain and platform credentials location
- ✅ Container image URI and registry credentials

## What's NOT Included (Uses Defaults)

The following optional features use their default values:

- **S3 Storage**: `rm_storage_manager = null` (no S3 bucket configured)
- **Integration Credentials**: `integration_credentials_arns = []` (no additional secrets)
- **Monitoring**: No CloudWatch alarms (no SNS topic specified)
- **Log Encryption**: CloudWatch logs are unencrypted
- **Additional IAM Policies**: `tasks_iam_role_policies = []` (no custom policies)
- **Custom Log Configuration**: Uses default CloudWatch logging
- **ECS Cluster**: Module creates a new cluster

## Prerequisites

Before deploying this example, you need:

1. **VPC with private subnets** in at least 2 different availability zones
2. **NAT Gateway or VPC endpoints** for AWS service access (ECR, Secrets Manager, CloudWatch)
3. **Secrets in AWS Secrets Manager**:
   - DataGrail platform credentials
   - DataGrail image registry credentials

For detailed prerequisites, see the main [README](../../README.md#prerequisites).

## Usage

1. **Create a new directory for your RM Agent configuration:**
   ```bash
   mkdir rm-agent && cd rm-agent
   ```

2. **Create a `main.tf` with the minimum required configuration:**
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
   }
   ```

3. **Review the [example configuration](./main.tf)** in this directory for a complete reference.

4. **Deploy:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Next Steps

After deploying the minimum example:

1. **Verify deployment** - See [Monitoring and Validation](../../README.md#monitoring-and-validation)
2. **Add monitoring** - Configure CloudWatch alarms with an SNS topic
3. **Enable S3 storage** - Add `rm_storage_manager` configuration
4. **Add integration credentials** - Use `integration_credentials_arns` for database access
5. **Review the [Complete Example](../complete/)** for additional features

## Additional Documentation

For detailed information, see the main [README](../../README.md):

- [Architecture](../../README.md#architecture)
- [AWS Infrastructure Requirements](../../README.md#aws-infrastructure-requirements)
- [Cost Considerations](../../README.md#cost-considerations)
- [Troubleshooting](../../README.md#troubleshooting)
