################################################################################
# ECS Cluster
################################################################################

output "cluster_arn" {
  description = "ARN of the ECS cluster (either created or provided via var.cluster_arn)"
  value       = try(aws_ecs_cluster.rm_agent[0].arn, var.cluster_arn)
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = try(aws_ecs_cluster.rm_agent[0].name, split("/", var.cluster_arn)[1])
}

################################################################################
# ECS Service
################################################################################

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.service.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.service.id
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.rm_agent.arn
}

################################################################################
# Security Group
################################################################################

output "security_group_id" {
  description = "ID of the security group attached to the ECS service"
  value       = aws_security_group.service.id
}

output "security_group_arn" {
  description = "ARN of the security group attached to the ECS service"
  value       = aws_security_group.service.arn
}

################################################################################
# IAM Roles
################################################################################

output "task_execution_role_arn" {
  description = "ARN of the task execution IAM role (either created or provided)"
  value       = try(data.aws_iam_role.task_exec[0].arn, aws_iam_role.task_exec[0].arn)
}

output "task_execution_role_name" {
  description = "Name of the task execution IAM role"
  value       = try(data.aws_iam_role.task_exec[0].name, aws_iam_role.task_exec[0].name)
}

output "task_role_arn" {
  description = "ARN of the task IAM role"
  value       = aws_iam_role.tasks.arn
}

output "task_role_name" {
  description = "Name of the task IAM role"
  value       = aws_iam_role.tasks.name
}

################################################################################
# CloudWatch Logs
################################################################################

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group (if enabled)"
  value       = var.enable_cloudwatch_logging ? try(aws_cloudwatch_log_group.logs[0].name, var.cloudwatch_log_group_name) : null
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group (if enabled)"
  value       = var.enable_cloudwatch_logging ? try(aws_cloudwatch_log_group.logs[0].arn, null) : null
}

output "cloudwatch_log_group_encrypted" {
  description = "Whether the CloudWatch log group is encrypted with KMS"
  value       = var.enable_cloudwatch_logging && var.cloudwatch_log_group_kms_key_id != null
}

################################################################################
# Network Configuration
################################################################################

output "egress_configuration" {
  description = "Egress configuration with actual resource IDs for network troubleshooting and documentation"
  value = {
    datagrail_api = {
      cidr_block             = var.datagrail_api_cidr
      port                   = 443
      security_group_rule_id = aws_vpc_security_group_egress_rule.service_to_datagrail_api.id
    }
    s3 = try(var.rm_storage_manager.bucket, null) != null ? {
      enabled                = var.enable_s3_prefix_list_egress
      prefix_list_id         = var.enable_s3_prefix_list_egress ? data.aws_prefix_list.s3[0].id : null
      prefix_list_name       = var.enable_s3_prefix_list_egress ? data.aws_prefix_list.s3[0].name : null
      security_group_rule_id = var.enable_s3_prefix_list_egress ? aws_vpc_security_group_egress_rule.service_to_s3[0].id : null
    } : null
    secrets_manager = var.secrets_manager_vpc_endpoint_sg_id != null && var.rm_credentials_manager.provider == "AWSSecretsManager" ? {
      using_vpc_endpoint     = true
      vpc_endpoint_sg_id     = var.secrets_manager_vpc_endpoint_sg_id
      security_group_rule_id = aws_vpc_security_group_egress_rule.service_to_secrets_manager_vpce[0].id
    } : null
    ssm_parameter_store = var.ssm_vpc_endpoint_sg_id != null && var.rm_credentials_manager.provider == "AWSParameterStore" ? {
      using_vpc_endpoint     = true
      vpc_endpoint_sg_id     = var.ssm_vpc_endpoint_sg_id
      security_group_rule_id = aws_vpc_security_group_egress_rule.service_to_ssm_vpce[0].id
    } : null
    ecr = {
      api = var.ecr_api_vpc_endpoint_sg_id != null ? {
        using_vpc_endpoint     = true
        vpc_endpoint_sg_id     = var.ecr_api_vpc_endpoint_sg_id
        security_group_rule_id = aws_vpc_security_group_egress_rule.service_to_ecr_api_vpce[0].id
      } : null
      dkr = var.ecr_dkr_vpc_endpoint_sg_id != null ? {
        using_vpc_endpoint     = true
        vpc_endpoint_sg_id     = var.ecr_dkr_vpc_endpoint_sg_id
        security_group_rule_id = aws_vpc_security_group_egress_rule.service_to_ecr_dkr_vpce[0].id
      } : null
    }
    redis = var.rm_redis_url != null ? {
      enabled                = true
      port                   = 6379
      security_group_rule_id = aws_vpc_security_group_egress_rule.service_to_redis[0].id
    } : null
    aws_services_fallback = {
      enabled = (
        var.secrets_manager_vpc_endpoint_sg_id == null ||
        var.ssm_vpc_endpoint_sg_id == null ||
        var.ecr_api_vpc_endpoint_sg_id == null ||
        var.ecr_dkr_vpc_endpoint_sg_id == null
      )
      security_group_rule_id = (
        var.secrets_manager_vpc_endpoint_sg_id == null ||
        var.ssm_vpc_endpoint_sg_id == null ||
        var.ecr_api_vpc_endpoint_sg_id == null ||
        var.ecr_dkr_vpc_endpoint_sg_id == null
      ) ? aws_vpc_security_group_egress_rule.service_to_aws_services[0].id : null
      note = "This fallback rule allows 0.0.0.0/0:443 for any AWS services without VPC endpoints configured"
    }
  }
}

################################################################################
# CloudWatch Alarms
################################################################################

output "cloudwatch_alarms_enabled" {
  description = "Whether CloudWatch alarms are enabled (based on presence of alarm_sns_topic_arn)"
  value       = var.alarm_sns_topic_arn != null
}

output "cloudwatch_alarm_arns" {
  description = "ARNs of CloudWatch alarms (if alarm_sns_topic_arn is provided)"
  value = var.alarm_sns_topic_arn != null ? {
    cpu_utilization    = try(aws_cloudwatch_metric_alarm.cpu_utilization[0].arn, null)
    memory_utilization = try(aws_cloudwatch_metric_alarm.memory_utilization[0].arn, null)
    running_task_count = try(aws_cloudwatch_metric_alarm.running_task_count[0].arn, null)
  } : null
}

output "task_stopped_event_rule_arn" {
  description = "ARN of the EventBridge rule for task stopped events (if alarm_sns_topic_arn is provided)"
  value       = var.alarm_sns_topic_arn != null ? try(aws_cloudwatch_event_rule.task_stopped[0].arn, null) : null
}

################################################################################
# Network Validation
################################################################################

output "subnet_availability_zones" {
  description = "Availability zones of the configured subnets"
  value       = local.subnet_azs
}

output "unique_availability_zone_count" {
  description = "Number of unique availability zones across configured subnets"
  value       = length(local.unique_azs)
}