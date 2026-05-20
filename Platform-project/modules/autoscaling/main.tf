# Register the ECS service with Application Auto Scaling
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_tasks   # never scale above this
  min_capacity       = var.min_tasks   # never scale below this
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
 
# ── Scale OUT policy — add containers when CPU is high ───────────────────
resource "aws_appautoscaling_policy" "cpu_scale_out" {
  name               = "bcsap1-cpu-scale-out-${var.env}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
 
  target_tracking_scaling_policy_configuration {
    # Target: keep average CPU at 65%
    # If CPU > 65%, add containers. If CPU < 65%, remove them.
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 65.0
    scale_in_cooldown  = 300   # wait 5 min before scaling in (avoid flapping)
    scale_out_cooldown = 60    # scale out quickly when under load
  }
}
 
# ── Scale on memory too ───────────────────────────────────────────────────
resource "aws_appautoscaling_policy" "memory_scale" {
  name               = "bcsap1-memory-scale-${var.env}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
 
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 75.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
 
# ── Scheduled scaling — scale down overnight to save money ───────────────
resource "aws_appautoscaling_scheduled_action" "scale_down_night" {
  name               = "bcsap1-scale-down-night-${var.env}"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  schedule           = "cron(0 20 * * ? *)"   # 8pm UTC (9pm BST)
 
  scalable_target_action {
    min_capacity = 1
    max_capacity = 2
  }
}
 
resource "aws_appautoscaling_scheduled_action" "scale_up_morning" {
  name               = "bcsap1-scale-up-morning-${var.env}"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  schedule           = "cron(0 7 * * ? *)"   # 7am UTC (8am BST)
 
  scalable_target_action {
    min_capacity = var.min_tasks
    max_capacity = var.max_tasks
  }
}
 
# ── CloudWatch alarm: notify when scaling happens ─────────────────────────
resource "aws_cloudwatch_metric_alarm" "cpu_high_alarm" {
  alarm_name          = "bcsap1-cpu-high-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
 
  dimensions = {
    ServiceName = var.service_name
    ClusterName = var.cluster_name
  }
 
  alarm_description = "BCSAP1 ECS CPU above 80% for 2 minutes"
  treat_missing_data = "notBreaching"
}
