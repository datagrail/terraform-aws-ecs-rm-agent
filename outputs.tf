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