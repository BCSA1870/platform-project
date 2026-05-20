# ── Execution Role ────────────────────────────────────────────────────────
# AWS uses this to start your container. Needs ECR pull + CloudWatch log write.
resource "aws_iam_role" "execution" {
  name = "bcsap1-ecs-execution-${var.env}"
 
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
 
  tags = { Name = "BCSAP1-ECS-Execution", Environment = var.env }
}
 
# AWS-managed policy covering ECR pull + CloudWatch log creation
resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
 
# ── Task Role ─────────────────────────────────────────────────────────────
# Your application code runs as this role. Only grant what the app actually needs.
resource "aws_iam_role" "task" {
  name = "bcsap1-ecs-task-${var.env}"
 
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
 
  tags = { Name = "BCSAP1-ECS-Task", Environment = var.env }
}
 
resource "aws_iam_role_policy" "task_logs" {
  name = "bcsap1-task-logs-${var.env}"
  role = aws_iam_role.task.id
 
  # Principle of Least Privilege: only exactly what the app needs
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:eu-west-2:*:log-group:/ecs/*"
      },
      # Add more permissions here as your app needs them
      # Example: S3 read access
      # {
      #   Effect   = "Allow"
      #   Action   = ["s3:GetObject", "s3:ListBucket"]
      #   Resource = ["arn:aws:s3:::my-app-bucket", "arn:aws:s3:::my-app-bucket/*"]
      # }
    ]
  })
}
 
variable "env" { default = "dev" }
