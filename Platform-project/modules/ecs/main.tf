resource "aws_ecs_cluster" "this" {
  name = "bcsap1-cluster-${var.env}"
 
  setting {
    name  = "containerInsights"
    value = "enabled"   # enables CloudWatch Container Insights metrics
  }
 
  tags = { Name = "BCSAP1-Cluster", Environment = var.env }
}
 
# CloudWatch log group for app container output
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/bcsap1-app-${var.env}"
  retention_in_days = 14
  tags              = { Environment = var.env }
}
 
# Task definition — the "job description" for your container
resource "aws_ecs_task_definition" "app" {
  family                   = "bcsap1-app-${var.env}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"   # required for Fargate
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
 
  container_definitions = jsonencode([{
    name  = "app"
    image = var.image
 
    portMappings = [{
      containerPort = 5000
      protocol      = "tcp"
    }]
 
    # Environment variables passed to your app
    environment = [
      { name = "ENV",  value = var.env },
      { name = "PORT", value = "5000" }
    ]
 
    # Health check — ECS restarts container if this fails 3 times
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
 
    # All stdout/stderr goes to CloudWatch
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/bcsap1-app-${var.env}"
        "awslogs-region"        = "eu-west-2"
        "awslogs-stream-prefix" = "app"
      }
    }
  }])
 
  tags = { Environment = var.env }
}
 
# ECS Service — keeps desired_count containers running at all times
resource "aws_ecs_service" "app" {
  name            = "bcsap1-app-service-${var.env}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
 
  network_configuration {
    subnets          = [var.private_subnet_a]
    security_groups  = [var.ecs_sg]
    assign_public_ip = false   # private subnet — no public IP
  }
 
  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = 5000
  }
 
  # Allow CI/CD to update the task definition without Terraform reverting it
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
 
  # Wait for ALB to be ready before registering
  depends_on = [var.alb_listener_arn]
 
  tags = { Name = "BCSAP1-App-Service", Environment = var.env }
}
