variable "project_name" {
  description = "The name of the project. The value will be used in resource names as a prefix."
  type        = string
  default     = "rm-agent"
}

################################################################################
# Environment Variables
################################################################################

variable "rm_customer_domain" {
  description = "The fully qualified domain name of your DataGrail environment, e.g. 'acme.datagrail.io'"
  type        = string
}

variable "rm_storage_manager" {
  description = "The name of the S3 bucket to store access and identifier request results. This *must* be the same bucket integrated with DataGrail."
  type = object({
    provider = string
    bucket   = string
  })
  default = null
}

variable "rm_platform_credentials_location" {
  description = "The ARN of the DataGrail platform API key in Secrets Manager or Parameter Store. For more information on creating the secret, see the [DataGrail Platform API Key](./README.md#callback-token) section in the README."
  type        = string
}

variable "rm_credentials_manager" {
  description = "The credentials manager used to store the the DataGrail platform API key and connector credentials."
  type = object({
    provider = string
  })
  default = { provider : "AWSSecretsManager" }
  validation {
    condition     = contains(["AWSSecretsManager", "AWSParameterStore"], var.rm_credentials_manager.provider)
    error_message = "The 'credentials_manager.provider' variable must be set to 'AWSSecretsManager' or 'AWSParameterStore'."
  }
}

variable "rm_redis_url" {
  description = "Connection string for a remote Redis instance."
  type        = string
  default     = null
}

variable "rm_job_timeout" {
  description = "Max time (seconds) for a single job before timeout"
  type        = number
  default     = null
}

variable "loglevel" {
  description = "The loglevel for the `rm-agent` container.\n**WARNING:** The `DEBUG` loglevel will expose PII and credentials."
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["INFO", "DEBUG", "WARNING"], upper(var.loglevel))
    error_message = "Loglevel must be INFO, DEBUG, or WARNING."
  }
}

################################################################################
# VPC
################################################################################

variable "vpc_id" {
  description = "The ID of the VPC to place the Agent into."
  type        = string
}

variable "private_subnet_ids" {
  description = "The ID(s) of the private subnet(s) to put the `rm-agent` ECS task(s) into."
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets must be specified."
  }
}

variable "datagrail_api_cidr" {
  description = "CIDR block for DataGrail API VPC (cross-account). Defaults to 172.31.0.0/16."
  type        = string
  default     = "172.31.0.0/16"
}

variable "additional_egress_cidrs" {
  description = "Additional CIDR blocks to allow HTTPS egress to (e.g., for VPC endpoints or other APIs)."
  type        = list(string)
  default     = []
}

variable "enable_s3_prefix_list_egress" {
  description = "Enable egress to S3 using AWS managed prefix list. Set to false if using S3 VPC Gateway Endpoint."
  type        = bool
  default     = true
}

################################################################################
# VPC Endpoint Security Groups (Optional)
################################################################################

variable "secrets_manager_vpc_endpoint_sg_id" {
  description = "Security group ID of the Secrets Manager VPC endpoint. If provided, creates egress rule to this SG instead of 0.0.0.0/0:443."
  type        = string
  default     = null
}

variable "ssm_vpc_endpoint_sg_id" {
  description = "Security group ID of the SSM (Parameter Store) VPC endpoint. If provided, creates egress rule to this SG instead of 0.0.0.0/0:443."
  type        = string
  default     = null
}

variable "ecr_api_vpc_endpoint_sg_id" {
  description = "Security group ID of the ECR API VPC endpoint. If provided, creates egress rule to this SG instead of 0.0.0.0/0:443."
  type        = string
  default     = null
}

variable "ecr_dkr_vpc_endpoint_sg_id" {
  description = "Security group ID of the ECR DKR (Docker registry) VPC endpoint. If provided, creates egress rule to this SG instead of 0.0.0.0/0:443."
  type        = string
  default     = null
}

################################################################################
# ECS Service Deployment Configuration
################################################################################

variable "desired_count" {
  description = "Number of task instances to run. For high availability, set to 2 or more."
  type        = number
  default     = 1
  validation {
    condition     = var.desired_count >= 0
    error_message = "desired_count must be a non-negative integer."
  }
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower limit on the number of tasks that must remain running during a deployment, as a percentage of desired_count."
  type        = number
  default     = 100
  validation {
    condition     = var.deployment_minimum_healthy_percent >= 0 && var.deployment_minimum_healthy_percent <= 100
    error_message = "deployment_minimum_healthy_percent must be between 0 and 100."
  }
}

variable "deployment_maximum_percent" {
  description = "Upper limit on the number of tasks that can run during a deployment, as a percentage of desired_count."
  type        = number
  default     = 200
  validation {
    condition     = var.deployment_maximum_percent >= 100
    error_message = "deployment_maximum_percent must be at least 100."
  }
}

variable "enable_deployment_circuit_breaker" {
  description = "Enable deployment circuit breaker to automatically roll back failed deployments."
  type        = bool
  default     = true
}

variable "enable_ecs_managed_tags" {
  description = "Enable ECS-managed tags for the service."
  type        = bool
  default     = true
}

variable "propagate_tags" {
  description = "Specifies whether to propagate tags from the task definition or service to tasks. Valid values: TASK_DEFINITION, SERVICE, or NONE."
  type        = string
  default     = "SERVICE"
  validation {
    condition     = contains(["TASK_DEFINITION", "SERVICE", "NONE"], var.propagate_tags)
    error_message = "propagate_tags must be one of: TASK_DEFINITION, SERVICE, or NONE."
  }
}

################################################################################
# Tagging
################################################################################

variable "tags" {
  description = "A map of tags to apply to all resources created by this module. These will be merged with default tags."
  type        = map(string)
  default     = {}
}


################################################################################
# Task Execution - IAM Role
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
################################################################################

variable "task_exec_iam_role_name" {
  description = "The name of an existing task execution role to use."
  type        = string
  default     = null
}

################################################################################
# Tasks - IAM role
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html
################################################################################

variable "tasks_iam_role_policies" {
  description = "List of additional IAM role policy ARNs to attach to the IAM task role."
  type        = list(string)
  default     = []
}

################################################################################
# CloudWatch
################################################################################

variable "enable_cloudwatch_logging" {
  description = "Determines whether CloudWatch logging is configured for this container definition. Set to `false` to use other logging drivers."
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_name" {
  description = "Name of CloudWatch log group for ECS cluster."
  type        = string
  default     = null
}

variable "cloudwatch_log_retention_in_days" {
  description = "The retention period (in days) of the agent's CloudWatch log group."
  type        = number
  default     = 30
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "The ARN of the KMS key to use for CloudWatch log encryption. If not provided, logs will not be encrypted."
  type        = string
  default     = null
}

################################################################################
# CloudWatch Alarms
################################################################################

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications. If provided, CloudWatch alarms will be created for CPU utilization, memory utilization, running task count, and task stopped events."
  type        = string
  default     = null
}

variable "alarm_cpu_threshold" {
  description = "CPU utilization threshold (percentage) for CloudWatch alarm."
  type        = number
  default     = 80
  validation {
    condition     = var.alarm_cpu_threshold > 0 && var.alarm_cpu_threshold <= 100
    error_message = "alarm_cpu_threshold must be between 0 and 100."
  }
}

variable "alarm_memory_threshold" {
  description = "Memory utilization threshold (percentage) for CloudWatch alarm."
  type        = number
  default     = 80
  validation {
    condition     = var.alarm_memory_threshold > 0 && var.alarm_memory_threshold <= 100
    error_message = "alarm_memory_threshold must be between 0 and 100."
  }
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarm state."
  type        = number
  default     = 2
  validation {
    condition     = var.alarm_evaluation_periods >= 1
    error_message = "alarm_evaluation_periods must be at least 1."
  }
}

variable "log_configuration" {
  description = "The log configuration for the container. For more information see [LogConfiguration](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LogConfiguration.html)"
  type = object({
    logDriver = optional(string)
    options   = optional(map(string))
    secretOptions = optional(list(object({
      name      = string
      valueFrom = string
    })))
  })
  default = {}
}

################################################################################
# Cluster
################################################################################

variable "cluster_arn" {
  description = "ARN of an existing ECS cluster to place the tasks."
  type        = string
  default     = null
}

################################################################################
# Task Definition
################################################################################

variable "agent_container_image" {
  description = "The URI of the agent image."
  type        = string
}

variable "agent_container_cpu" {
  description = "The CPU allotted for the agent container."
  type        = number
  default     = 1024
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.agent_container_cpu)
    error_message = "CPU must be a valid Fargate value: 256, 512, 1024, 2048, or 4096."
  }
}

variable "agent_container_memory" {
  description = "The memory allotted for the agent container."
  type        = number
  default     = 2048
  validation {
    condition = (
      # 256 CPU: 512, 1024, 2048 MB
      (var.agent_container_cpu == 256 && contains([512, 1024, 2048], var.agent_container_memory)) ||
      # 512 CPU: 1024, 2048, 3072, 4096 MB
      (var.agent_container_cpu == 512 && contains([1024, 2048, 3072, 4096], var.agent_container_memory)) ||
      # 1024 CPU: 2048-8192 MB in 1024 MB increments
      (var.agent_container_cpu == 1024 && var.agent_container_memory >= 2048 && var.agent_container_memory <= 8192 && var.agent_container_memory % 1024 == 0) ||
      # 2048 CPU: 4096-16384 MB in 1024 MB increments
      (var.agent_container_cpu == 2048 && var.agent_container_memory >= 4096 && var.agent_container_memory <= 16384 && var.agent_container_memory % 1024 == 0) ||
      # 4096 CPU: 8192-30720 MB in 1024 MB increments
      (var.agent_container_cpu == 4096 && var.agent_container_memory >= 8192 && var.agent_container_memory <= 30720 && var.agent_container_memory % 1024 == 0)
    )
    error_message = <<-EOT
      Invalid CPU/Memory combination for Fargate. Valid combinations:
      - 256 CPU: 512, 1024, 2048 MB
      - 512 CPU: 1024, 2048, 3072, 4096 MB
      - 1024 CPU: 2048-8192 MB (1024 MB increments)
      - 2048 CPU: 4096-16384 MB (1024 MB increments)
      - 4096 CPU: 8192-30720 MB (1024 MB increments)
    EOT
  }
}

################################################################################
# Secrets
################################################################################

variable "rm_agent_image_registry_credentials_arn" {
  description = "The ARN of the DataGrail Docker image registry credentials in AWS Secrets Manager. For more information on creating the secret, see the [Docker Image Registry Credentials](./README.md#docker-image-registry-credentials) section in the README."
  type        = string
}
