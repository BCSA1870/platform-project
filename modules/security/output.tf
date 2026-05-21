output "alb_sg"        { value = aws_security_group.alb.id }
output "ecs_sg"        { value = aws_security_group.ecs.id }
output "monitoring_sg" { value = aws_security_group.monitoring.id }
