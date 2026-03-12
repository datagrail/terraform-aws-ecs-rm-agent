provider "aws" {
  region  = "us-west-2"
  profile = "datagrail-terraform-dev"
}

module "rm_agent" {
  source = "../.."

  # Required: VPC Configuration
  vpc_id             = "vpc-06a6d2e823178cee7"
  private_subnet_ids = ["subnet-00e6202bdf6f103ae", "subnet-07e7666b20930cb59"]

  # Required: DataGrail Configuration
  rm_customer_domain               = "solutions.datagrail.io"
  rm_platform_credentials_location = "arn:aws:secretsmanager:us-west-2:158714794554:secret:datagrail.platform_api_key-z0mKCI"

  # Required: Container Configuration
  agent_container_image                   = "contairium.datagrail.io/rm-agent:v1.0.2"
  rm_agent_image_registry_credentials_arn = "arn:aws:secretsmanager:us-west-2:158714794554:secret:datagrail.rm-agent.image-registry-uaaPm4"

  # All other variables use their default values:
  # - project_name: "rm-agent"
  # - rm_credentials_manager: { provider = "AWSSecretsManager" }
  # - rm_storage_manager: null (no S3 storage)
  # - loglevel: "INFO"
  # - agent_container_cpu: 1024
  # - agent_container_memory: 2048
  # - desired_count: 1
  # - enable_cloudwatch_logging: true
  # - enable_deployment_circuit_breaker: true
  # - datagrail_api_cidr: "172.31.0.0/16"
}