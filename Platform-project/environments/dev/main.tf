provider "aws" {
  region = var.region
 
  default_tags {
    tags = {
      Project     = "BCSAP1"
      Environment = var.env
      ManagedBy   = "Terraform"
      Owner       = "Platform Engineering"
    }
  }
}
 
# ── 1. Network Foundation ──────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"
  env    = var.env
  region = var.region
}
 
# ── 2. Security Groups ─────────────────────────────────────────────────────
module "security" {
  source = "../../modules/security"
  vpc_id = module.vpc.vpc_id
  env    = var.env
}
 
# ── 3. IAM Roles ───────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"
  env    = var.env
}
 
# ── 4. HTTPS Certificate (skip if no domain yet) ───────────────────────────
# module "acm" {
#   source      = "../../modules/acm"
#   domain_name = var.domain_name
# }
 
# ── 5. Load Balancer ───────────────────────────────────────────────────────
module "alb" {
  source           = "../../modules/alb"
  vpc_id           = module.vpc.vpc_id
  public_subnet_a  = module.vpc.public_subnet_a
  public_subnet_b  = module.vpc.public_subnet_b
  alb_sg           = module.security.alb_sg
  # certificate_arn = module.acm.certificate_arn   # uncomment when ACM ready
  env              = var.env
}
 
# ── 6. ECS Cluster + App Service ───────────────────────────────────────────
module "ecs" {
  source             = "../../modules/ecs"
  image              = var.image
  private_subnet_a   = module.vpc.private_subnet_a
  ecs_sg             = module.security.ecs_sg
  target_group_arn   = module.alb.target_group_arn
  execution_role_arn = module.iam.execution_role_arn
  task_role_arn      = module.iam.task_role_arn
  alb_listener_arn   = module.alb.https_listener_arn
  task_cpu           = var.task_cpu
  task_memory        = var.task_memory
  desired_count      = var.desired_count
  env                = var.env
}
 
# ── 7. Autoscaling ─────────────────────────────────────────────────────────
module "autoscaling" {
  source       = "../../modules/autoscaling"
  cluster_name = module.ecs.cluster_name
  service_name = module.ecs.service_name
  min_tasks    = var.min_tasks
  max_tasks    = var.max_tasks
  env          = var.env
}
 
# ── 8. Monitoring Stack ────────────────────────────────────────────────────
module "monitoring" {
  source             = "../../modules/monitoring"
  cluster_id         = module.ecs.cluster_id
  private_subnet_a   = module.vpc.private_subnet_a
  ecs_sg             = module.security.ecs_sg
  monitoring_sg      = module.security.monitoring_sg
  execution_role_arn = module.iam.execution_role_arn
  task_role_arn      = module.iam.task_role_arn
  env                = var.env
}
 
# ── Outputs ────────────────────────────────────────────────────────────────
output "alb_dns" {
  value       = module.alb.alb_dns
  description = "Paste this into your browser to test"
}