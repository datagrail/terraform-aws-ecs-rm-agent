data "aws_region" "current" {}

data "aws_subnet" "private" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}

data "aws_route_table" "private" {
  for_each  = toset(var.private_subnet_ids)
  subnet_id = each.value
}

locals {
  default_tags = {
    ManagedBy = "Terraform"
    Module    = "terraform-aws-ecs-rm-agent"
  }
  tags = merge(local.default_tags, var.tags)

  # Extract availability zones from subnets
  subnet_azs = [for subnet in data.aws_subnet.private : subnet.availability_zone]

  # Check if subnets are in different AZs
  unique_azs = distinct(local.subnet_azs)

  # Check if any route table has an IGW route (0.0.0.0/0 -> igw-*)
  # Private subnets should NOT have direct IGW routes
  subnets_with_igw = [
    for rt_id, rt in data.aws_route_table.private : rt_id
    if length([
      for route in rt.routes : route
      if route.cidr_block == "0.0.0.0/0" && can(regex("^igw-", route.gateway_id))
    ]) > 0
  ]
}

################################################################################
# Task Execution - IAM Role
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
################################################################################

data "aws_iam_role" "task_exec" {
  count = var.task_exec_iam_role_name == null ? 0 : 1

  name = var.task_exec_iam_role_name
}

data "aws_iam_policy_document" "task_exec_assume" {
  count = var.task_exec_iam_role_name == null ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "task_exec_secrets" {
  statement {
    sid = "SecretsManagerGetSecretValue"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      var.rm_agent_image_registry_credentials_arn
    ]
  }
}

resource "aws_iam_role" "task_exec" {
  count              = var.task_exec_iam_role_name == null ? 1 : 0
  name               = "${substr(var.project_name, 0, 49)}-task-exec-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.task_exec_assume[0].json
  tags               = local.tags
}

resource "aws_iam_role_policy" "task_exec" {
  name   = "datagrail-image-repo-credentials-access"
  role   = try(data.aws_iam_role.task_exec[0].id, aws_iam_role.task_exec[0].id)
  policy = data.aws_iam_policy_document.task_exec_secrets.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
  count      = var.task_exec_iam_role_name == null ? 1 : 0
  role       = aws_iam_role.task_exec[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

################################################################################
# Tasks - IAM role
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html
################################################################################

data "aws_iam_policy_document" "tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "tasks" {
  dynamic "statement" {
    for_each = try(var.rm_storage_manager.bucket, null) != null ? [1] : []
    content {
      sid = "S3PutObject"

      actions = [
        "s3:PutObject"
      ]

      resources = [
        "arn:aws:s3:::${var.rm_storage_manager.bucket}/*"
      ]
    }
  }

  dynamic "statement" {
    for_each = var.rm_credentials_manager.provider == "AWSSecretsManager" ? [1] : []
    content {
      sid = "SecretsManagerGetSecretValue"

      actions = [
        "secretsmanager:GetSecretValue"
      ]

      resources = concat(
        [var.rm_platform_credentials_location]
      )
    }
  }

  dynamic "statement" {
    for_each = var.rm_credentials_manager.provider == "AWSParameterStore" ? [1] : []
    content {
      sid = "ParameterStoreGetParameter"

      actions = [
        "ssm:GetParameter"
      ]

      resources = concat(
        [var.rm_platform_credentials_location]
      )
    }
  }

  dynamic "statement" {
    for_each = length(var.integration_credentials_arns) > 0 ? [1] : []
    content {
      sid = "IntegrationCredentialsAccess"

      actions = [
        "secretsmanager:GetSecretValue",
        "ssm:GetParameter"
      ]

      resources = var.integration_credentials_arns
    }
  }
}

resource "aws_iam_role" "tasks" {
  name               = "${substr(var.project_name, 0, 53)}-tasks-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.tasks_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy" "tasks" {
  name   = "${var.project_name}-task-role-policy"
  role   = aws_iam_role.tasks.id
  policy = data.aws_iam_policy_document.tasks.json
}

resource "aws_iam_role_policy_attachment" "tasks_additional_policies" {
  for_each = toset(var.tasks_iam_role_policies)

  role       = aws_iam_role.tasks.name
  policy_arn = each.key
}

################################################################################
# CloudWatch
################################################################################

locals {
  default_log_config = var.enable_cloudwatch_logging ? {
    logDriver = "awslogs"
    options = {
      awslogs-region        = data.aws_region.current.id,
      awslogs-group         = aws_cloudwatch_log_group.logs[0].name,
      awslogs-stream-prefix = "ecs"
    }
    } : {
    logDriver = null
    options   = {}
  }

  log_configuration = length(keys(var.log_configuration)) > 0 ? {
    logDriver = coalesce(var.log_configuration.logDriver, local.default_log_config.logDriver)
    options = merge(
      try(local.default_log_config.options, {}),
      try(var.log_configuration.options, {})
    )
    secretOptions = try(var.log_configuration.secretOptions, null)
  } : null
}

resource "aws_cloudwatch_log_group" "logs" {
  count             = var.enable_cloudwatch_logging ? 1 : 0
  name              = coalesce(var.cloudwatch_log_group_name, "/aws/ecs/${var.project_name}")
  retention_in_days = var.cloudwatch_log_retention_in_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id
  tags              = local.tags
}

################################################################################
# Cluster
################################################################################

resource "aws_ecs_cluster" "rm_agent" {
  count = var.cluster_arn == null ? 1 : 0
  name  = "${var.project_name}-cluster"
  tags  = local.tags
}

################################################################################
# Task Definition
################################################################################

resource "aws_ecs_task_definition" "rm_agent" {
  family                   = var.project_name
  execution_role_arn       = try(data.aws_iam_role.task_exec[0].arn, aws_iam_role.task_exec[0].arn)
  task_role_arn            = aws_iam_role.tasks.arn
  cpu                      = var.agent_container_cpu
  memory                   = var.agent_container_memory
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  tags                     = local.tags

  container_definitions = jsonencode([
    {
      name             = var.project_name
      logConfiguration = local.log_configuration
      command = [
        "supervisord",
        "-n",
        "-c",
        "/etc/rm.conf"
      ],
      environment = [
        for env in [
          {
            name  = "RM_CUSTOMER_DOMAIN"
            value = var.rm_customer_domain
          },
          {
            name  = "RM_PLATFORM_CREDENTIALS_LOCATION"
            value = var.rm_platform_credentials_location
          },
          {
            name  = "RM_CREDENTIALS_MANAGER"
            value = jsonencode(var.rm_credentials_manager)
          },
          {
            name  = "RM_STORAGE_MANAGER"
            value = var.rm_storage_manager != null ? jsonencode(var.rm_storage_manager) : null
          },
          {
            name  = "RM_JOB_TIMEOUT_SECONDS"
            value = var.rm_job_timeout
          },
          {
            name  = "LOGLEVEL"
            value = upper(var.loglevel)
          }
        ] : env if env.value != null
      ]
      cpu   = 0
      image = var.agent_container_image
      repositoryCredentials = {
        credentialsParameter = var.rm_agent_image_registry_credentials_arn
      }
      healthCheck = {
        "retries" = 3
        "command" = [
          "CMD-SHELL",
          "test -f /app/healthy || exit 1"
        ],
        "timeout"     = 5
        "interval"    = 30
        "startPeriod" = 30
      },
      essential    = true
      skip_destroy = true
    }
  ])
}

################################################################################
# Service
################################################################################

resource "aws_security_group" "service" {
  name        = "${var.project_name}-service-sg"
  vpc_id      = var.vpc_id
  description = "Security group attached to the ${var.project_name} service."
  tags        = local.tags
}

# HTTPS egress for DataGrail API and AWS services
# Domain-based filtering is handled at the application layer via rm_customer_domain
# VPC endpoints automatically used if configured in the VPC
resource "aws_vpc_security_group_egress_rule" "service_to_https" {
  security_group_id = aws_security_group.service.id

  description = "HTTPS egress for DataGrail API and AWS services (S3, Secrets Manager, ECR, etc.)"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

resource "aws_ecs_service" "service" {
  name            = "${var.project_name}-service"
  cluster         = try(aws_ecs_cluster.rm_agent[0].arn, var.cluster_arn)
  task_definition = aws_ecs_task_definition.rm_agent.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  # Enforce single-task: max 1 task during deployments (brief downtime)
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  enable_ecs_managed_tags            = var.enable_ecs_managed_tags
  propagate_tags                     = var.propagate_tags
  tags                               = local.tags

  deployment_circuit_breaker {
    enable   = var.enable_deployment_circuit_breaker
    rollback = var.enable_deployment_circuit_breaker
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    assign_public_ip = false
    security_groups  = [aws_security_group.service.id]
  }

  lifecycle {
    precondition {
      condition     = length(local.unique_azs) >= 2
      error_message = "Subnets must be in at least 2 different availability zones for high availability. Found ${length(local.unique_azs)} unique AZ(s): ${join(", ", local.unique_azs)}"
    }

    precondition {
      condition     = length(local.subnets_with_igw) == 0
      error_message = "All subnets must be private (no direct Internet Gateway routes). Found ${length(local.subnets_with_igw)} subnet(s) with IGW routes: ${join(", ", local.subnets_with_igw)}. Use subnets with NAT Gateway or VPC endpoints instead."
    }
  }
}

################################################################################
# CloudWatch Alarms
################################################################################

resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count = var.alarm_sns_topic_arn != null ? 1 : 0

  alarm_name          = "${var.project_name}-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.alarm_cpu_threshold
  alarm_description   = "Triggers when CPU utilization exceeds ${var.alarm_cpu_threshold}% for ${var.alarm_evaluation_periods} consecutive periods"
  alarm_actions       = [var.alarm_sns_topic_arn]
  treat_missing_data  = "notBreaching"
  tags                = local.tags

  dimensions = {
    ClusterName = try(aws_ecs_cluster.rm_agent[0].name, split("/", var.cluster_arn)[1])
    ServiceName = aws_ecs_service.service.name
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization" {
  count = var.alarm_sns_topic_arn != null ? 1 : 0

  alarm_name          = "${var.project_name}-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.alarm_memory_threshold
  alarm_description   = "Triggers when memory utilization exceeds ${var.alarm_memory_threshold}% for ${var.alarm_evaluation_periods} consecutive periods"
  alarm_actions       = [var.alarm_sns_topic_arn]
  treat_missing_data  = "notBreaching"
  tags                = local.tags

  dimensions = {
    ClusterName = try(aws_ecs_cluster.rm_agent[0].name, split("/", var.cluster_arn)[1])
    ServiceName = aws_ecs_service.service.name
  }
}

resource "aws_cloudwatch_metric_alarm" "running_task_count" {
  count = var.alarm_sns_topic_arn != null ? 1 : 0

  alarm_name          = "${var.project_name}-running-task-count"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Triggers when running task count is less than 1"
  alarm_actions       = [var.alarm_sns_topic_arn]
  treat_missing_data  = "breaching"
  tags                = local.tags

  dimensions = {
    ClusterName = try(aws_ecs_cluster.rm_agent[0].name, split("/", var.cluster_arn)[1])
    ServiceName = aws_ecs_service.service.name
  }
}

################################################################################
# EventBridge Rule for Task State Changes
################################################################################

resource "aws_cloudwatch_event_rule" "task_stopped" {
  count = var.alarm_sns_topic_arn != null ? 1 : 0

  name        = "${var.project_name}-task-stopped"
  description = "Captures ECS task stopped/failed events for ${var.project_name}"
  tags        = local.tags

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      clusterArn    = [try(aws_ecs_cluster.rm_agent[0].arn, var.cluster_arn)]
      lastStatus    = ["STOPPED"]
      desiredStatus = ["STOPPED"]
      stoppedReason = [{ "exists" : true }]
    }
  })
}

resource "aws_cloudwatch_event_target" "task_stopped_sns" {
  count = var.alarm_sns_topic_arn != null ? 1 : 0

  rule      = aws_cloudwatch_event_rule.task_stopped[0].name
  target_id = "SendToSNS"
  arn       = var.alarm_sns_topic_arn

  input_transformer {
    input_paths = {
      taskArn       = "$.detail.taskArn"
      stoppedReason = "$.detail.stoppedReason"
      stoppedAt     = "$.detail.stoppedAt"
      clusterArn    = "$.detail.clusterArn"
    }
    input_template = "\"ECS Task Stopped: <taskArn> in cluster <clusterArn>. Reason: <stoppedReason>. Stopped at: <stoppedAt>\""
  }
}
