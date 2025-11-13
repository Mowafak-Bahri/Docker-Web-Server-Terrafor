terraform {
  backend "s3" {
    # **Configure these settings for your environment:**
    bucket = "YOUR_S3_BACKEND_BUCKET_NAME"    # Replace with your S3 bucket name
    key    = "nginx-docker-ec2/terraform.tfstate"  # Path within the bucket for state file
    region = "ca-central-1"
    # (Optional: For state locking, you can add "dynamodb_table = <YOUR_LOCK_TABLE>" if using DynamoDB)
  }
}
