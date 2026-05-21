output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "alb_dns" {
  value = aws_lb.this.dns_name
}

output "alb_arn" {
  value = aws_lb.this.arn
}

# Outputs the HTTP listener ARN for now
# When HTTPS is enabled, change this to aws_lb_listener.https.arn
output "https_listener_arn" {
  value = aws_lb_listener.http.arn
}
