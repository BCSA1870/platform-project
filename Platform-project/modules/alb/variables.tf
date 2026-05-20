variable "vpc_id"          { type = string }
variable "public_subnet_a" { type = string }
variable "public_subnet_b" { type = string }
variable "alb_sg"          { type = string }
variable "certificate_arn" {
  type    = string
  default = ""
}
variable "env"             { default = "dev" }

