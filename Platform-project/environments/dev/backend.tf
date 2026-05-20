terraform {
  backend "s3" {
    bucket         = "tf-state-bcsap1-001"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-lock-bcsap1"
    encrypt        = true   
  }
}
