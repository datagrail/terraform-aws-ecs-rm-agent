################################################################################
# Load Balancer
################################################################################

output "load_balancer_arn" {
  description = "The ARN of the agent load balancer."
  value       = aws_alb.datagrail_agent.arn
}

output "load_balancer_dns_name" {
  description = "The DNS name of the agent load balancer."
  value       = aws_alb.datagrail_agent.dns_name
}

################################################################################
# Route53 Record(s)
################################################################################

output "route53_record" {
  description = "The Route53 alias created and attached to the load balancer."
  value       = aws_route53_record.alb_alias
}