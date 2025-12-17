variable "project_name" {
  description = "The name of the project. The value will be used in resource names as a prefix."
  type        = string
  default     = "datagrail-rm-agent"
}

variable "connections" {
  description = "Connection objects to instantiate. More information can be found in the [documentations](https://docs.datagrail.io/docs/integrations/internal-systems-integrations/request-manager-agent/connections/request-manager-agent-connections-setup)."
  type = list(object({
    name           = string
    uuid           = string
    capabilities   = list(string)
    mode           = string
    connector_type = string
    queries = object({
      access      = optional(list(any), [])
      delete      = optional(list(any), [])
      optout      = optional(list(any), [])
      identifiers = optional(map(list(any)), {})
      test        = optional(list(any), [])
    })
    credentials_location = string
  }))
  default = []
}

variable "customer_domain" {
  description = "The fully qualified domain name of your DataGrail environment, e.g. 'acme.datagrail.io'"
  type        = string
}

variable "bucket_name" {
  description = "The name of the S3 bucket to store access and identifier request results. This *must* be the same bucket integrated with DataGrail."
  type        = string
}

variable "credentials_manager" {
  description = "The credentials manager used to store the credentials made available to the agent, e.g. the agent's OAuth client credentials, DataGrail callback token, and connector credentials."
  type        = string
  default     = "AWSSecretsManager"
  validation {
    condition     = contains(["AWSSecretsManager", "AWSParameterStore"], var.credentials_manager)
    error_message = "The 'credentials_manager' variable must be set to 'AWSSecretsManager' or 'AWSParameterStore'."
  }
}

variable "loglevel" {
  description = "The loglevel for the `datagrail-rm-agent` container.\n**WARNING:** The `DEBUG` loglevel will expose PII and credentials."
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["INFO", "DEBUG"], upper(var.loglevel))
    error_message = "Loglevel must be INFO or DEBUG."
  }
}

############
# VPC
############

variable "vpc_id" {
  description = "The ID of the VPC to place the agent into."
  type        = string
}

variable "public_subnet_ids" {
  description = "The IDs of the public subnets for the load balancer to be placed into."
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least two public subnets must be specified."
  }
}

variable "private_subnet_ids" {
  description = "The ID(s) of the private subnet(s) to put the datagrail-rm-agent ECS task(s) into."
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets must be specified."
  }
}

################################################################################
# Load Balancer
################################################################################

variable "load_balancer_ingress_rules" {
  description = "Additional ingress rules for the load balancer security group."
  type = map(object({
    cidr_ipv4   = optional(string)
    cidr_ipv6   = optional(string)
    description = optional(string)
  }))
  default = {}
}

variable "load_balancer_ssl_policy" {
  description = "Load balancer SSL policy."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}


variable "certificate_arn" {
  description = "The ARN of the TLS certificate for the load balancer."
  type        = string
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

variable "datagrail_callback_token_arn" {
  description = "The ARN of the callback token in Secrets Manager or Parameter Store. For more information on creating the secret, see the [Callback Token](./README.md#callback-token) section in the README."
  type        = string
}

variable "datagrail_agent_client_credentials_arn" {
  description = "The ARN of the Request Manager Agent Client Credentials in Secrets Manager or Parameter Store. FOr more information on creating the secret, see the "
  type        = string
}

################################################################################
# Route53 Record
################################################################################

variable "agent_subdomain" {
  description = "The subdomain of the agent."
  type        = string
  default     = "datagrail-rm-agent"
}

variable "hosted_zone_name" {
  description = "The name of the Route53 hosted zone where the public DataGrail agent subdomain will be created."
  type        = string
  default     = null
}
