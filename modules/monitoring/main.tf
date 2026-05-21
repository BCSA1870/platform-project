resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/bcsap1-prometheus-${var.env}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/bcsap1-grafana-${var.env}"
  retention_in_days = 7
}

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
    image = "prom/prometheus:v2.48.0"

    portMappings = [{ containerPort = 9090, protocol = "tcp" }]

    command = [
      "--config.file=/etc/prometheus/prometheus.yml",
      "--storage.tsdb.retention.time=7d",
      "--web.enable-lifecycle"
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
      { name = "GF_SECURITY_ADMIN_PASSWORD", value = "BcsapAdmin2024!" },
      { name = "GF_USERS_ALLOW_SIGN_UP",     value = "false" },
      { name = "GF_SERVER_HTTP_PORT",         value = "3000" }
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

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "BCSAP1-${var.env}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ECS CPU Utilisation"
          region  = "eu-west-2"
          view    = "timeSeries"
          stacked = false
          stat    = "Average"
          period  = 60
          annotations = { horizontal = [] }
          metrics = [
            ["AWS/ECS", "CPUUtilization",
              "ClusterName", "bcsap1-cluster-${var.env}"]
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ECS Memory Utilisation"
          region  = "eu-west-2"
          view    = "timeSeries"
          stacked = false
          stat    = "Average"
          period  = 60
          annotations = { horizontal = [] }
          metrics = [
            ["AWS/ECS", "MemoryUtilization",
              "ClusterName", "bcsap1-cluster-${var.env}"]
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB Request Count"
          region  = "eu-west-2"
          view    = "timeSeries"
          stacked = false
          stat    = "Sum"
          period  = 60
          annotations = { horizontal = [] }
          metrics = [
            ["AWS/ApplicationELB", "RequestCount",
              "LoadBalancer", "app/bcsap1-alb-${var.env}"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB 5xx Errors"
          region  = "eu-west-2"
          view    = "timeSeries"
          stacked = false
          stat    = "Sum"
          period  = 60
          annotations = {
            horizontal = [
              { label = "Alert", value = 10, color = "#d62728" }
            ]
          }
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count",
              "LoadBalancer", "app/bcsap1-alb-${var.env}"]
          ]
        }
      }
    ]
  })
}
