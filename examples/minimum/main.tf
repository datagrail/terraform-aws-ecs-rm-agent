provider "aws" {
  region  = "us-west-2"
  profile = "datagrail-terraform-dev"
}

module "rm_agent" {
  source = "git::https://github.com/datagrail/terraform-aws-ecs-rm-agent.git?ref=v0.0.1"

  # Required: VPC Configuration
  vpc_id             = "vpc-XXXX"
  private_subnet_ids = ["subnet-XXXX", "subnet-XXXX"]

  # Required: DataGrail Configuration
  rm_customer_domain               = "example.datagrail.io"
  rm_platform_credentials_location = "arn:aws:secretsmanager:us-west-2:XXXX:secret:datagrail/platform_api_key"

  # Required: Container Configuration
  agent_container_image                   = "contairium.datagrail.io/rm-agent:v1.0.2"
  rm_agent_image_registry_credentials_arn = "arn:aws:secretsmanager:us-west-2:XXXX:secret:datagrail/rm-agent/image-registry"

  integration_credentials_arns = ["arn:aws:secretsmanager:us-west-2:XXXX:secret:datagrail-agent/snowflake"]
  # All other variables use their default values:
  # - project_name: "rm-agent"
  # - rm_credentials_manager: { provider = "AWSSecretsManager" }
  # - rm_storage_manager: null (no S3 storage)
  # - loglevel: "INFO"
  # - agent_container_cpu: 1024
  # - agent_container_memory: 2048
  # - enable_cloudwatch_logging: true
  # - enable_deployment_circuit_breaker: true
}