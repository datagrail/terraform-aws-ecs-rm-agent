provider "aws" {
  region = "us-west-2"
  # profile = "your-aws-profile" # Uncomment and set your AWS profile if needed
}

################################################################################
# Complete Example - All Configuration Options
################################################################################

module "rm_agent" {
  source = "../.."

  # Project Configuration
  project_name = "rm-agent-prod"

  ################################################################################
  # VPC and Network Configuration
  ################################################################################

  vpc_id             = "vpc-XXXX"
  private_subnet_ids = ["subnet-XXXX", "subnet-YYYY"]

  ################################################################################
  # DataGrail Environment Configuration
  ################################################################################

  rm_customer_domain = "example.datagrail.io"

  # Storage configuration
  rm_storage_manager = {
    provider = "AWSS3"
    bucket   = "datagrail-rm-agent-results"
  }

  # Credentials manager
  rm_credentials_manager = {
    provider = "AWSSecretsManager" # or "AWSParameterStore"
  }

  # Platform credentials location
  rm_platform_credentials_location = "arn:aws:secretsmanager:us-west-2:XXXX:secret:datagrail/platform-credentials"

  # Optional: Integration credentials (database connections, external APIs)
  integration_credentials_arns = [
    # "arn:aws:secretsmanager:us-west-2:XXXX:secret:mysql-db-credentials",
    # "arn:aws:ssm:us-west-2:XXXX:parameter/postgres/connection",
  ]

  # Optional: Job timeout in seconds
  rm_job_timeout = 3600

  # Log level
  loglevel = "INFO" # INFO, DEBUG, WARNING

  ################################################################################
  # ECS Cluster Configuration
  ################################################################################

  # Optional: Use existing cluster
  cluster_arn = null # "arn:aws:ecs:us-west-2:XXXX:cluster/my-cluster"

  ################################################################################
  # ECS Task Configuration
  ################################################################################

  # Container image
  agent_container_image                   = "contairium.datagrail.io/rm-agent:v1.0.2"
  rm_agent_image_registry_credentials_arn = "arn:aws:secretsmanager:us-west-2:XXXX:secret:datagrail/image-registry-credentials"

  # CPU and Memory (must be valid Fargate combinations)
  agent_container_cpu    = 1024
  agent_container_memory = 2048

  ################################################################################
  # ECS Service Configuration
  ################################################################################

  # Deployment configuration
  enable_deployment_circuit_breaker = true
  enable_ecs_managed_tags           = true
  propagate_tags                    = "SERVICE" # TASK_DEFINITION, SERVICE, or NONE

  ################################################################################
  # IAM Configuration
  ################################################################################

  # Optional: Use existing task execution role
  task_exec_iam_role_name = null

  # Optional: Additional IAM policies for task role
  tasks_iam_role_policies = [
    # "arn:aws:iam::aws:policy/CustomPolicy"
  ]

  ################################################################################
  # CloudWatch Logging
  ################################################################################

  enable_cloudwatch_logging        = true
  cloudwatch_log_group_name        = "/aws/ecs/rm-agent-prod"
  cloudwatch_log_retention_in_days = 90

  # Log encryption with KMS
  cloudwatch_log_group_kms_key_id = null # "arn:aws:kms:us-west-2:XXXX:key/abc-123"

  # Optional: Custom log configuration
  log_configuration = {
    # logDriver = "awslogs"  # Uncomment to override
    # options = {
    #   "awslogs-create-group" = "true"
    # }
  }

  ################################################################################
  # CloudWatch Alarms (Optional but Recommended for Production)
  ################################################################################

  # Enable alarms by providing an SNS topic
  alarm_sns_topic_arn = null # "arn:aws:sns:us-west-2:XXXX:ops-alerts"

  # Alarm thresholds
  alarm_cpu_threshold      = 80
  alarm_memory_threshold   = 80
  alarm_evaluation_periods = 2

  ################################################################################
  # Resource Tagging
  ################################################################################

  tags = {
    Environment = "production"
    Team        = "platform"
    CostCenter  = "engineering"
    Project     = "data-privacy"
    ManagedBy   = "Terraform"
    Application = "datagrail-rm-agent"
    Compliance  = "SOC2"
  }
}

################################################################################
# Outputs
################################################################################

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.rm_agent.cluster_arn
}

output "service_name" {
  description = "ECS service name"
  value       = module.rm_agent.service_name
}

output "service_arn" {
  description = "ECS service ARN"
  value       = module.rm_agent.service_arn
}

output "security_group_id" {
  description = "Security group ID"
  value       = module.rm_agent.security_group_id
}

output "task_role_arn" {
  description = "Task IAM role ARN"
  value       = module.rm_agent.task_role_arn
}

output "task_execution_role_arn" {
  description = "Task execution IAM role ARN"
  value       = module.rm_agent.task_execution_role_arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = module.rm_agent.cloudwatch_log_group_name
}
