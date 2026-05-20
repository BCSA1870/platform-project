# ── CloudWatch Log Groups ─────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/bcsap1-prometheus-${var.env}"
  retention_in_days = 7
}
 
resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/bcsap1-grafana-${var.env}"
  retention_in_days = 7
}
 
# ── Prometheus ────────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "prometheus" {
  family                   = "bcsap1-prometheus-${var.env}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
 
  container_definitions = jsonencode([{
    name  = "prometheus"
    image = "prom/prometheus:v2.48.0"   # pin versions in production
 
    portMappings = [{ containerPort = 9090, protocol = "tcp" }]
 
    command = [
      "--config.file=/etc/prometheus/prometheus.yml",
      "--storage.tsdb.retention.time=7d",
      "--web.enable-lifecycle"   # allows config reload without restart
    ]
 
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/bcsap1-prometheus-${var.env}"
        "awslogs-region"        = "eu-west-2"
        "awslogs-stream-prefix" = "prometheus"
      }
    }
  }])
}
 
resource "aws_ecs_service" "prometheus" {
  name            = "bcsap1-prometheus-${var.env}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"
 
  network_configuration {
    subnets          = [var.private_subnet_a]
    security_groups  = [var.ecs_sg]
    assign_public_ip = false
  }
}
 
# ── Grafana ───────────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "grafana" {
  family                   = "bcsap1-grafana-${var.env}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
 
  container_definitions = jsonencode([{
    name  = "grafana"
    image = "grafana/grafana:10.2.0"
 
    portMappings = [{ containerPort = 3000, protocol = "tcp" }]
 
    environment = [
      { name = "GF_SECURITY_ADMIN_PASSWORD", value = "change-me-in-prod-use-secrets-manager!" },
      { name = "GF_USERS_ALLOW_SIGN_UP",     value = "false" },
      { name = "GF_SERVER_ROOT_URL",          value = "https://${var.domain}/grafana" }
    ]
 
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/bcsap1-grafana-${var.env}"
        "awslogs-region"        = "eu-west-2"
        "awslogs-stream-prefix" = "grafana"
      }
    }
  }])
}
 
resource "aws_ecs_service" "grafana" {
  name            = "bcsap1-grafana-${var.env}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"
 
  network_configuration {
    subnets          = [var.private_subnet_a]
    security_groups  = [var.monitoring_sg]
    assign_public_ip = false
  }
}
 
# ── CloudWatch Dashboard ──────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "BCSAP1-${var.env}"
 
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title   = "ECS CPU Utilisation"
          metrics = [["AWS/ECS", "CPUUtilization", "ClusterName", "bcsap1-cluster-${var.env}"]]
          period  = 60
          stat    = "Average"
          view    = "timeSeries"
        }
      },
      {
        type = "metric"
        properties = {
          title   = "ECS Memory Utilisation"
          metrics = [["AWS/ECS", "MemoryUtilization", "ClusterName", "bcsap1-cluster-${var.env}"]]
          period  = 60
          stat    = "Average"
        }
      },
      {
        type = "metric"
        properties = {
          title   = "ALB Request Count"
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "bcsap1-alb-${var.env}"]]
          period  = 60
          stat    = "Sum"
        }
      }
    ]
  })
}
