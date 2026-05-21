variable "cluster_id"          { type = string }
variable "private_subnet_a"   { type = string }
variable "ecs_sg"             { type = string }
variable "monitoring_sg"      { type = string }
variable "execution_role_arn" { type = string }
variable "task_role_arn"      { type = string }
variable "domain"             { default = "localhost" }
variable "env"                { default = "dev" }