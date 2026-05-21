data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "bcsap1-alb-logs-${var.env}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket     = aws_s3_bucket.alb_logs.id
  depends_on = [aws_s3_bucket_public_access_block.alb_logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSELBLogDelivery"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::652711504416:root" }
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::bcsap1-alb-logs-${var.env}-${data.aws_caller_identity.current.account_id}/alb-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Sid       = "AWSLogDeliveryAclCheck"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = "arn:aws:s3:::bcsap1-alb-logs-${var.env}-${data.aws_caller_identity.current.account_id}"
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    expiration { days = 30 }
  }
}

resource "aws_lb" "this" {
  name               = "bcsap1-alb-${var.env}"
  load_balancer_type = "application"
  subnets            = [var.public_subnet_a, var.public_subnet_b]
  security_groups    = [var.alb_sg]
  idle_timeout       = 60

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb-logs"
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.alb_logs]

  tags = { Name = "BCSAP1-ALB", Environment = var.env }
}

resource "aws_lb_target_group" "this" {
  name        = "bcsap1-tg-${var.env}"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

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

# HTTP listener — forwards traffic to ECS
# When you add an ACM cert later, replace this with a redirect
# and add the aws_lb_listener.https resource below it
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# HTTPS listener — uncomment when ACM certificate is ready
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.this.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = var.certificate_arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.this.arn
#   }
# }
