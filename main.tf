data "aws_region" "current" {}

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
      var.image_registry_credentials_arn
    ]
  }
}

resource "aws_iam_role" "task_exec" {
  count              = var.task_exec_iam_role_name == null ? 1 : 0
  name               = "${substr(var.project_name, 0, 49)}-task-exec-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.task_exec_assume[0].json
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
    for_each = var.rm_storage_manager.bucket != null ? [1] : []
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
}

resource "aws_iam_role" "tasks" {
  name               = "${substr(var.project_name, 0, 53)}-tasks-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.tasks_assume.json
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
      awslogs-group         = try(aws_cloudwatch_log_group.logs[0].name, var.cloudwatch_log_group_name),
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
}

################################################################################
# Cluster
################################################################################

resource "aws_ecs_cluster" "rm_agent" {
  count = var.cluster_arn == null ? 1 : 0
  name  = "${var.project_name}-cluster"
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
            value = jsonencode(var.rm_storage_manager)
          },
          {
            name  = "RM_REDIS_URL"
            value = var.rm_redis_url
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
        credentialsParameter = var.image_registry_credentials_arn
      }
      healthCheck = {
        "retries" = 3
        "command" = [
          "CMD-SHELL",
          "test -f /app/healthy || exit 1"
        ],
        "timeout"     = 5
        "interval"    = 30
        "startPeriod" = 120
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
}

resource "aws_vpc_security_group_egress_rule" "service_to_anywhere" {
  security_group_id = aws_security_group.service.id

  description = "Allow rm-agent service egress to anywhere."
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_ecs_service" "service" {
  name            = "${var.project_name}-service"
  cluster         = try(aws_ecs_cluster.rm_agent[0].arn, var.cluster_arn)
  task_definition = aws_ecs_task_definition.rm_agent.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.private_subnet_ids
    assign_public_ip = false
    security_groups  = [aws_security_group.service.id]
  }
}
