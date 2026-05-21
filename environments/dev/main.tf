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

module "vpc" {
  source = "../../modules/vpc"
  env    = var.env
  region = var.region
}

module "security" {
  source = "../../modules/security"
  vpc_id = module.vpc.vpc_id
  env    = var.env
}

module "iam" {
  source = "../../modules/iam"
  env    = var.env
}

module "alb" {
  source          = "../../modules/alb"
  vpc_id          = module.vpc.vpc_id
  public_subnet_a = module.vpc.public_subnet_a
  public_subnet_b = module.vpc.public_subnet_b
  alb_sg          = module.security.alb_sg
  env             = var.env
}

module "ecs" {
  source             = "../../modules/ecs"
  image              = var.image
  private_subnet_a   = module.vpc.private_subnet_a
  ecs_sg             = module.security.ecs_sg
  target_group_arn   = module.alb.target_group_arn
  execution_role_arn = module.iam.execution_role_arn
  task_role_arn      = module.iam.task_role_arn
  alb_listener_arn   = module.alb.https_listener_arn
  env                = var.env
}

module "autoscaling" {
  source       = "../../modules/autoscaling"
  cluster_name = module.ecs.cluster_name
  service_name = module.ecs.service_name
  min_tasks    = var.min_tasks
  max_tasks    = var.max_tasks
  env          = var.env
}

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

output "alb_dns" {
  value       = module.alb.alb_dns
  description = "Paste this into your browser to test"
}
