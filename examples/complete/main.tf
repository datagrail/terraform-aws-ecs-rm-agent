provider "aws" {
  region  = "us-west-2"
  profile = "datagrail-terraform-dev"
}

module "datagrail-rm-agent" {
  source = "../.."

  # VPC
  vpc_id             = "vpc-XXXX"
  public_subnet_ids  = ["subnet-XXXX", "subnet-XXXX"]
  private_subnet_ids = ["subnet-XXXX", "subnet-XXXX"]


  # DATAGRAIL_AGENT_CONFIG environment variable
  customer_domain                        = "example.datagrail.io"
  bucket_name                            = "datagrail-bucket"
  datagrail_callback_token_arn           = "arn:aws:secretsmanager:us-west-2:XXXX:secret:datagrail.rm-agent.callback"
  datagrail_agent_client_credentials_arn = "arn:aws:secretsmanager:us-west-2:XXXX:secret:datagrail.rm-agent.client-credentials"

  connections = [
    {
      name           = "Customer Database"
      uuid           = "ff95204a-56f8-4726-b541-56dfa4a2b507"
      capabilities   = ["privacy/delete", "privacy/identifiers", "privacy/access"]
      mode           = "live"
      connector_type = "Snowflake"
      queries = {
        access = ["CALL dsr('access', %(email)s)"]
        delete = ["CALL dsr('deletion', %(email)s)"]
        identifiers = {
          customer_id        = ["SELECT TO_VARCHAR(id) AS user_id FROM CUSTOMER.CUSTOMER WHERE EMAIL = %(email)s"]
          device_id          = ["SELECT TO_VARCHAR(DEVICE_ID) as service_id FROM CUSTOMER.DEVICE D JOIN CUSTOMER.CUSTOMER C ON D.USER_ID = C.ID WHERE EMAIL = %(email)s"]
          last_sign_in_ip    = ["SELECT TO_VARCHAR(LAST_SIGN_IN_IP) AS browser_id from CUSTOMER.CUSTOMER C JOIN CUSTOMER.DEVICE D ON C.ID = D.USER_ID WHERE C.EMAIL = %(email)s"]
          current_sign_in_ip = ["SELECT TO_VARCHAR(CURRENT_SIGN_IN_IP) AS browser_id from CUSTOMER.CUSTOMER C JOIN CUSTOMER.DEVICE D ON C.ID = D.USER_ID WHERE C.EMAIL = %(email)s"]
        }
      }
      credentials_location = "arn:aws:secretsmanager:us-west-2:XXXX:secret:datagrail.rm-agent.snowflake"
    },
    {
      name           = "Device Database"
      uuid           = "a2b55762-0aa8-4872-8bc3-1ff908f7ebf7"
      capabilities   = ["privacy/delete", "privacy/access"]
      mode           = "live"
      connector_type = "Snowflake"
      queries = {
        access = ["SELECT * FROM CUSTOMER.DEVICE WHERE DEVICE_ID = %(service_id)s"]
        delete = ["DELETE FROM CUSTOMER.DEVICE WHERE DEVICE_ID = %(service_id)s"]
      }
      credentials_location = "arn:aws:secretsmanager:us-west-2:XXXX:secret:datagrail.rm-agent.snowflake"
    }
  ]

  # Additional Application Load Balancer Security Group rules
  load_balancer_ingress_rules = {
    local-machine = {
      description = "Allow ingress from local machine for testing."
      cidr_ipv4   = "245.11.82.175/32"
    }
  }

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

  # Route53/Certificate Manager
  hosted_zone_name = "dg-taylor.com"
  agent_subdomain  = "rm-agent"
  certificate_arn  = "arn:aws:acm:us-west-2:XXXX:certificate/14f3f47d-e653-4856-a01a-40d0e64df244"

}