# Deploying Nginx Docker on AWS EC2 with Terraform

This project contains code to deploy a custom Nginx web server (in a Docker container) on an AWS EC2 instance using Terraform. It creates a Free Tier eligible EC2 (t2.micro) in the **ca-central-1** region with Docker installed and running Nginx serving a custom `index.html`. Terraform will also set up an S3 backend for remote state storage.

## Project Structure

- **docker/**: Docker image content (Dockerfile and custom `index.html` for Nginx).
- **terraform/**: Terraform configuration files to provision AWS resources (EC2, Security Group, etc.).
- **scripts/**: Shell scripts for automation (e.g., EC2 user-data script to install Docker and run the container).
- **Makefile**: Convenience make targets to run Terraform commands.
- **.env.example**: Example environment variables for AWS credentials.
- **.gitignore**: Git ignore rules (to exclude Terraform state, variables, etc.).

## Prerequisites

- **AWS Account** with access to create EC2, S3, and related resources.
- **AWS CLI** configured or environment variables set for AWS credentials. (Terraform will use these to authenticate.)
- **Terraform** installed on your system.
- An S3 bucket (in `ca-central-1`) for storing the Terraform state (and an optional DynamoDB table for state locking, recommended but not required for this demo).
- (Optional) **Docker** installed locally if you want to build/test the Docker image manually, but not required for deployment since the EC2 instance will build and run the image.

## Usage

1. **Backend Setup**: Update the `terraform/backend.tf` file with your S3 bucket name (and adjust the key/path if desired). Create the S3 bucket beforehand. For team environments, it's recommended to also configure a DynamoDB table for state locking (not included by default).
2. **Configure Variables**: Review `terraform/variables.tf`. The default AWS region is `ca-central-1` and instance type is `t2.micro` (Free Tier). No SSH key is configured by default. If you need SSH access, you can add a key pair name to the Terraform configuration (and open port 22 in the security group).
3. **Initialize Terraform**:  
   - Using makefile: run `make init` to initialize the Terraform backend and provider.  
   - Or manually: `terraform -chdir=terraform init`.
4. **Review and Apply**:  
   - Optionally run `make plan` (or `terraform -chdir=terraform plan`) to review the planned changes.  
   - Deploy the infrastructure with `make apply` (or `terraform -chdir=terraform apply`). Terraform will provision the EC2 instance, security group, etc. 
5. **Deployment Output**: After apply, Terraform will output the EC2 instance's public IP and a URL. You can use the IP or URL to test the deployment.
6. **Test the Web Server**: In your browser or via curl, open `http://<EC2_PUBLIC_IP>`. You should see the custom HTML page served by Nginx (which confirms Docker and Nginx are running on the instance).
7. **Cleanup**: When finished, destroy the resources to avoid ongoing charges (though a t2.micro on Free Tier has no cost up to certain usage): run `make destroy` (or `terraform -chdir=terraform destroy`). This will terminate the EC2 instance and remove associated resources. Remember to delete the Terraform state files from the S3 bucket if you are discarding the project.

## How it Works

- **Docker**: The `docker/Dockerfile` is based on the official Nginx image and simply adds a custom `index.html` to replace the default Nginx welcome page. This image is built on the EC2 instance at startup.
- **EC2 User Data**: The EC2 instance is an Amazon Linux 2 server. On launch, a user-data shell script (`scripts/user_data.sh`) runs to install Docker, build the Docker image from the included Dockerfile and index.html, and run the Nginx container exposing port 80.
- **Terraform**: Terraform config (`terraform/main.tf` and related files) defines the infrastructure:
  - An EC2 instance (t2.micro, Amazon Linux 2) in the default VPC of **ca-central-1**.
  - A Security Group that allows inbound HTTP (port 80) from anywhere.
  - The EC2 instance is configured with the user-data script for automatic provisioning.
  - The Terraform state is stored remotely in the specified S3 bucket (`backend.tf` configures this).
- **Security**: For simplicity, port 80 is open to the world. No SSH access is configured by default (for true production use, you might want to include a key pair and open port 22 for SSH, or use Session Manager, etc.). The S3 backend ensures state is persisted and shareable if working in a team.

## Notes

- All components are within Free Tier usage limits (single t2.micro instance, minimal S3 storage for state). Ensure you destroy the resources when not needed.
- You can customize the `index.html` content or other parameters (like region or instance type) by editing the files before deployment.
- If you encounter any issues, make sure your AWS credentials are properly configured and that the AWS region in Terraform variables matches your S3 bucket region for the backend.
