variable "cluster_name"  { type = string }
variable "service_name"  { type = string }
variable "min_tasks"     { default = 1 }
variable "max_tasks"     { default = 6 }
variable "env"           { default = "dev" }
