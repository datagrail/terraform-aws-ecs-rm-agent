provider "aws" {
  region  = "us-west-2"
  profile = "datagrail-terraform-dev"
}

module "rm-agent" {
  source = "../.."

  # VPC
  vpc_id             = "vpc-XXXX"
  private_subnet_ids = ["subnet-XXXX", "subnet-XXXX"]


  # Environment Variables
  rm_customer_domain               = "example.datagrail.io"
  rm_storage_manager               = "datagrail-bucket"
  rm_credentials_manager           = ""
  rm_platform_credentials_location = "arn:aws:secretsmanager:us-west-2:XXXX:secret:datagrail.rm-agent.callback"

  # ECS Task Definition and Service
  image_registry_credentials_arn = "arn:aws:secretsmanager:us-west-2:XXXX:secret:datagrail.rm-agent.image-registry"
  agent_container_image          = "contairium.datagrail.io/rm-agent:v0.14.0"
  agent_container_cpu            = 1024
  agent_container_memory         = 2048

  # CloudWatch
  enable_cloudwatch_logging        = true
  cloudwatch_log_group_name        = "/aws/ecs/rm-agent"
  cloudwatch_log_retention_in_days = 30
  loglevel                         = "DEBUG"

}