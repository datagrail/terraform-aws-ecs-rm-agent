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
  type        = string
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

############
# VPC
############

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
}

variable "agent_container_memory" {
  description = "The memory allotted for the agent container."
  type        = number
  default     = 2048
}

################################################################################
# Secrets
################################################################################

variable "image_registry_credentials_arn" {
  description = "The ARN of the DataGrail Docker image registry credentials in AWS Secrets Manager. For more information on creating the secret, see the [Docker Image Registry Credentials](./README.md#docker-image-registry-credentials) section in the README."
  type        = string
}
