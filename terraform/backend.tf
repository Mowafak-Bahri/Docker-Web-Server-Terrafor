terraform {
  backend "s3" {
    bucket = "mowafak-terraform-backend-001"
    key    = "terraform/state.tfstate"
    region = "ca-central-1"
  }
}
