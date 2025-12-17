data "aws_region" "current" {}

################################################################################
# Load Balancer
################################################################################

locals {
  container_port          = 8080
  datagrail_ingress_cidrs = ["52.36.177.91/32"]
}

resource "aws_security_group" "load_balancer_security_group" {
  name        = "${var.project_name}-lb-sg"
  vpc_id      = var.vpc_id
  description = "Security group attached to the ${var.project_name} load balancer"
}

resource "aws_vpc_security_group_ingress_rule" "datagrail_to_alb" {
  for_each = toset(local.datagrail_ingress_cidrs)

  security_group_id = aws_security_group.load_balancer_security_group.id

  description = "Allow load balancer ingress from DataGrail."
  cidr_ipv4   = each.value
  ip_protocol = "tcp"
  to_port     = 443
  from_port   = 443
}

resource "aws_vpc_security_group_ingress_rule" "additional_to_alb" {
  for_each = { for k, v in var.load_balancer_ingress_rules : k => v }

  security_group_id = aws_security_group.load_balancer_security_group.id

  description = try(each.value.description, null)
  cidr_ipv4   = try(each.value.cidr_ipv4, null)
  cidr_ipv6   = try(each.value.cidr_ipv6, null)
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_to_service" {
  security_group_id = aws_security_group.load_balancer_security_group.id

  referenced_security_group_id = aws_security_group.service.id
  description                  = "Allow load balancer egress to datagrail-rm-agent service"
  ip_protocol                  = "tcp"
  from_port                    = local.container_port
  to_port                      = local.container_port
}

resource "aws_alb_target_group" "datagrail_agent" {
  name        = "${var.project_name}-target-group"
  port        = local.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    path = "/"
  }
}

resource "aws_alb" "datagrail_agent" {
  name               = substr("${var.project_name}-lb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer_security_group.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.datagrail_agent.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.load_balancer_ssl_policy
  certificate_arn   = var.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.datagrail_agent.arn
  }
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
  statement {
    sid = "S3PutObject"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }

  dynamic "statement" {
    for_each = var.credentials_manager == "AWSSecretsManager" ? [1] : []
    content {
      sid = "SecretsManagerGetSecretValue"

      actions = [
        "secretsmanager:GetSecretValue"
      ]

      resources = concat(
        [var.datagrail_callback_token_arn,
        var.datagrail_agent_client_credentials_arn],
        [for connection in var.connections : connection.credentials_location]
      )
    }
  }

  dynamic "statement" {
    for_each = var.credentials_manager == "AWSParameterStore" ? [1] : []
    content {
      sid = "ParameterStoreGetParameter"

      actions = [
        "ssm:GetParameter"
      ]

      resources = concat(
        [var.datagrail_callback_token_arn,
        var.datagrail_agent_client_credentials_arn],
        [for connection in var.connections : connection.credentials_location]
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

resource "aws_ecs_cluster" "datagrail_agent" {
  count = var.cluster_arn == null ? 1 : 0
  name  = "${var.project_name}-cluster"
}

################################################################################
# Task Definition
################################################################################

locals {
  datagrail_agent_config = jsonencode({
    connections                          = var.connections,
    customer_domain                      = var.customer_domain
    datagrail_agent_credentials_location = var.datagrail_agent_client_credentials_arn
    datagrail_credentials_location       = var.datagrail_callback_token_arn
    platform = {
      storage_manager = {
        provider = "AWSS3",
        options = {
          bucket = var.bucket_name
        }
      }
      credentials_manager = {
        provider = var.credentials_manager
      }
    }
  })
}


resource "aws_ecs_task_definition" "datagrail_agent" {
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
      portMappings = [
        {
          "hostPort"      = local.container_port
          "containerPort" = local.container_port
          "protocol"      = "tcp"
        }
      ],
      command = [
        "supervisord",
        "-n",
        "-c",
        "/etc/rm.conf"
      ],
      environment = [
        {
          "name"  = "DATAGRAIL_AGENT_CONFIG"
          "value" = local.datagrail_agent_config
        },
        {
          "name"  = "LOGLEVEL"
          "value" = upper(var.loglevel)
        }
      ]
      cpu              = 0
      workingDirectory = "/app"
      image            = var.agent_container_image
      repositoryCredentials = {
        credentialsParameter = var.image_registry_credentials_arn
      }
      healthCheck = {
        "retries" = 3
        "command" = [
          "CMD-SHELL",
          "curl -f http://localhost:${local.container_port}/ || exit 1"
        ],
        "timeout"     = 5
        "interval"    = 30
        "startPeriod" = 1
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

resource "aws_vpc_security_group_ingress_rule" "service_from_alb" {
  security_group_id = aws_security_group.service.id

  description                  = "Allow datagrail-rm-agent service ingress from load balancer."
  referenced_security_group_id = aws_security_group.load_balancer_security_group.id
  ip_protocol                  = "tcp"
  from_port                    = local.container_port
  to_port                      = local.container_port
}

resource "aws_vpc_security_group_egress_rule" "service_to_anywhere" {
  security_group_id = aws_security_group.service.id

  description = "Allow datagrail-rm-agent service egress to anywhere."
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_ecs_service" "service" {
  name            = "${var.project_name}-service"
  cluster         = try(aws_ecs_cluster.datagrail_agent[0].arn, var.cluster_arn)
  task_definition = aws_ecs_task_definition.datagrail_agent.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_alb_target_group.datagrail_agent.arn
    container_name   = aws_ecs_task_definition.datagrail_agent.family
    container_port   = local.container_port
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    assign_public_ip = false
    security_groups  = [aws_security_group.service.id]
  }
}

################################################################################
# Route53 Record
################################################################################

data "aws_route53_zone" "this" {
  count        = var.hosted_zone_name == null ? 0 : 1
  name         = var.hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "alb_alias" {
  count   = var.hosted_zone_name == null ? 0 : 1
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = "${var.agent_subdomain}.${data.aws_route53_zone.this[0].name}"
  type    = "A"

  alias {
    name                   = aws_alb.datagrail_agent.dns_name
    zone_id                = aws_alb.datagrail_agent.zone_id
    evaluate_target_health = true
  }
}