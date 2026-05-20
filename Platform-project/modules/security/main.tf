resource "aws_security_group" "alb" {
  name        = "bcsap1-alb-sg-${var.env}"
  description = "Allow HTTP and HTTPS from internet to ALB"
  vpc_id      = var.vpc_id
 
  # Allow HTTP from anywhere (redirected to HTTPS)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }
 
  # Allow HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }
 
  # Allow all outbound (ALB needs to reach ECS and make health checks)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  tags = { Name = "BCSAP1-ALB-SG", Environment = var.env }
}
 
resource "aws_security_group" "ecs" {
  name        = "bcsap1-ecs-sg-${var.env}"
  description = "Allow traffic only from ALB to ECS containers"
  vpc_id      = var.vpc_id
 
  # Only accept traffic from the ALB security group — NOT from the internet
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "App traffic from ALB only"
  }
 
  # Also allow Prometheus to scrape metrics
  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Prometheus metrics"
  }
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound for image pulls, AWS API calls"
  }
 
  tags = { Name = "BCSAP1-ECS-SG", Environment = var.env }
}
 
resource "aws_security_group" "monitoring" {
  name        = "bcsap1-monitoring-sg-${var.env}"
  description = "Grafana dashboard access"
  vpc_id      = var.vpc_id
 
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Grafana from ALB"
  }
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  tags = { Name = "BCSAP1-Monitoring-SG", Environment = var.env }
}

