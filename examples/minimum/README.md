# Minimum Example

This example demonstrates the **minimum required configuration** to deploy the DataGrail RM Agent using this Terraform module.

## What's Included

This example only sets the **required variables** with no defaults:

- ✅ VPC and subnet configuration
- ✅ DataGrail customer domain and credentials location
- ✅ Container image and registry credentials

All other variables use their default values.

## What's NOT Included (Uses Defaults)

- **S3 Storage**: `rm_storage_manager = null` (no S3 bucket configured)
- **Redis**: `rm_redis_url = null` (no external Redis)
- **Monitoring**: No CloudWatch alarms (no SNS topic specified)
- **Log Encryption**: CloudWatch logs are unencrypted
- **High Availability**: `desired_count = 1` (single task instance)
- **VPC Endpoints**: No VPC endpoint security groups configured

## Prerequisites

Before deploying this example, you need:

1. **VPC with private subnets**
   - At least 2 private subnets in different availability zones
   - NAT Gateway or VPC endpoints for AWS services (S3, Secrets Manager, ECR)

2. **Secrets in AWS Secrets Manager**
   - DataGrail platform credentials secret
   - DataGrail image registry credentials secret

3. **Network Access**
   - Egress to DataGrail API CIDR: `172.31.0.0/16:443`
   - Egress to AWS services (ECR, Secrets Manager, CloudWatch Logs)

## Usage

1. Update the variable values in `main.tf`:
   ```hcl
   vpc_id             = "vpc-YOUR-VPC-ID"
   private_subnet_ids = ["subnet-XXXXXX", "subnet-YYYYYY"]
   rm_customer_domain = "your-company.datagrail.io"
   # ... update other ARNs
   ```

2. Initialize and apply:
   ```bash
   cd examples/minimum
   terraform init
   terraform plan
   terraform apply
   ```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_rm_agent"></a> [rm\_agent](#module\_rm\_agent) | ../.. | n/a |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->