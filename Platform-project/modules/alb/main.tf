resource "aws_lb" "this" {
  name               = "bcsap1-alb-${var.env}"
  load_balancer_type = "application"
 
  # ALB requires TWO subnets in different availability zones
  subnets = [var.public_subnet_a, var.public_subnet_b]
 
  security_groups    = [var.alb_sg]
  idle_timeout       = 60
 
  # Enable access logs for debugging and compliance
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb-logs"
    enabled = true
  }
 
  tags = { Name = "BCSAP1-ALB", Environment = var.env }
}
 
# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "bcsap1-alb-logs-${var.env}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}
 
data "aws_caller_identity" "current" {}
 
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    id     = "delete-old-logs"
    status = "Enabled"
    expiration { days = 30 }
  }
}
 
# Target group — the list of containers to send traffic to
resource "aws_lb_target_group" "this" {
  name        = "bcsap1-tg-${var.env}"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"   # REQUIRED for Fargate
 
  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
 
  tags = { Name = "BCSAP1-TG", Environment = var.env }
}
 
# HTTP listener — redirects all port 80 traffic to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
 
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"   # permanent redirect
    }
  }
}
 
# HTTPS listener — serves real traffic, uses your ACM certificate
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"  # TLS 1.3 preferred
  certificate_arn   = var.certificate_arn
 
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
