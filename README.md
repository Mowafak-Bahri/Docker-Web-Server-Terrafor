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

## Local Setup

1. **Install Terraform**:  
   - macOS (Homebrew): `brew tap hashicorp/tap && brew install hashicorp/tap/terraform`  
   - Windows (Chocolatey): `choco install terraform`  
   - Linux: download from [terraform.io/downloads](https://www.terraform.io/downloads.html) or use your distro’s package manager.
2. **Install AWS CLI v2**: Follow the [official instructions](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) for your OS, then run `aws configure` to supply your access key, secret, and default region.
3. **(Optional) Install GNU Make** if you want to use the helper targets (`make init`, `make plan`, etc.). Windows shells typically don’t include `make` by default, so either install it (e.g., via Chocolatey: `choco install make` or use Git Bash/MSYS distribution) or run the equivalent `terraform -chdir=terraform ...` commands manually.
3. **(Optional) Install Docker** if you want to test the container locally: [docker.com/get-started](https://www.docker.com/get-started).
4. **Clone this repo** and copy `.env.example` to `.env` if you want to use environment variables instead of `aws configure`. Keep credentials out of source control.

## Running the Project

1. **Backend Setup**: Update the `terraform/backend.tf` file with your S3 bucket name (and adjust the key/path if desired). Create the S3 bucket beforehand. For team environments, it's recommended to also configure a DynamoDB table for state locking (not included by default).
2. **Configure Variables**: Review `terraform/variables.tf`. The default AWS region is `ca-central-1` and instance type is `t2.micro` (Free Tier). No SSH key is configured by default; if you need SSH access, set the `key_name` variable to an existing EC2 key pair **and** add an additional security-group rule for port 22 (the supplied configuration intentionally keeps SSH closed).
   - If your AWS account has zonal capacity constraints, adjust `availability_zone` (defaults to `ca-central-1a`) to another zone that supports `t2.micro`.
3. **Initialize Terraform**:  
   - Using makefile: run `make init` to initialize the Terraform backend and provider.  
   - Or manually: `terraform -chdir=terraform init`.
4. **Review and Apply**:  
   - Optionally run `make plan` (or `terraform -chdir=terraform plan`) to review the planned changes.  
   - Deploy the infrastructure with `make apply` (or `terraform -chdir=terraform apply`). Terraform will provision the EC2 instance, security group, etc. 
5. **Deployment Output**: After apply, Terraform will output the EC2 instance's public IP and a URL. You can use the IP or URL to test the deployment.
6. **Test the Web Server**: In your browser or via curl, open `http://<EC2_PUBLIC_IP>`. You should see the custom HTML page served by Nginx (which confirms Docker and Nginx are running on the instance).
7. **Optional - GitHub Actions**: The workflow in `.github/workflows/terraform.yml` expects the repository secrets `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` so it can run `terraform plan` against your remote state backend. Add those secrets (with least-privilege IAM credentials) before enabling the workflow.
8. **Cleanup**: When finished, destroy the resources to avoid ongoing charges (though a t2.micro on Free Tier has no cost up to certain usage): run `make destroy` (or `terraform -chdir=terraform destroy`). This will terminate the EC2 instance and remove associated resources. Remember to delete the Terraform state files from the S3 bucket if you are discarding the project.

## How it Works

- **Docker**: The `docker/Dockerfile` is based on the official Nginx image and simply adds a custom `index.html` to replace the default Nginx welcome page. This image is built on the EC2 instance at startup.
- **EC2 User Data**: The EC2 instance is an Amazon Linux 2 server. On launch, Terraform injects the `scripts/user_data.sh` script, which installs Docker, enables it at boot, builds the custom image using the bundled Dockerfile + HTML, and runs the container with a restart policy so it survives reboots.
- **Terraform**: Terraform config (`terraform/main.tf` and related files) defines the infrastructure:
  - An EC2 instance (t2.micro, Amazon Linux 2) in the default VPC of **ca-central-1**.
  - A Security Group that allows inbound HTTP (port 80) from anywhere.
  - The EC2 instance is configured with the user-data script for automatic provisioning.
  - The Terraform state is stored remotely in the specified S3 bucket (`backend.tf` configures this).
- **Security**: For simplicity, port 80 is open to the world. No SSH access is configured by default; to enable it you must provide a key pair, add a port-22 ingress rule, and ensure IAM/security compliance. The S3 backend ensures state is persisted and shareable if working in a team (remember to update `terraform/backend.tf` with your bucket name and create the bucket ahead of time).

## Notes

- All components are within Free Tier usage limits (single t2.micro instance, minimal S3 storage for state). Ensure you destroy the resources when not needed.
- You can customize the `index.html` content or other parameters (like region or instance type) by editing the files before deployment.
- If you encounter any issues, make sure your AWS credentials are properly configured and that the AWS region in Terraform variables matches your S3 bucket region for the backend.

## Troubleshooting

- **`terraform init` fails with S3 backend errors**: Confirm the bucket in `terraform/backend.tf` exists in `ca-central-1` and that your IAM user has `s3:ListBucket`, `s3:GetObject`, and `s3:PutObject` permissions for the specified key.
- **`InvalidKeyPair.NotFound` during apply**: Either remove any non-null `key_name` or create/upload the matching key pair in EC2 before running Terraform.
- **Unable to reach the web server**: Verify the instance has a public IP (default VPC), security group allows inbound HTTP (port 80), and no network ACLs block the traffic. Use `aws ec2 describe-instances` to inspect status checks.
- **GitHub Actions workflow fails to plan**: Ensure repo secrets `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set, and that the IAM policy allows `terraform init/plan` operations (EC2 describe, S3 backend access).
- **Docker container stops after reboot**: The provided `scripts/user_data.sh` configures Docker with `systemctl enable` and a `--restart unless-stopped` policy. Re-run `terraform apply` if the script did not finish (check `/var/log/cloud-init-output.log`).

## Roadmap

- Implement HTTPS termination via AWS Certificate Manager and an Application Load Balancer while keeping Terraform modules modular.
- Add optional SSH access controlled via Session Manager or a locked-down `bastion` security-group toggle.
- Parameterize the backend configuration (bucket, key, region) via partial configuration files for easier reuse across environments.
- Extend GitHub Actions to run automated integration tests (e.g., curl the instance endpoint) after Terraform `apply` in non-prod workspaces.
- Add observability: CloudWatch Logs/metrics for Docker/Nginx plus alarms for instance health.
- Track development context and future plans in `docs/DEVELOPMENT_NOTES.md`.
