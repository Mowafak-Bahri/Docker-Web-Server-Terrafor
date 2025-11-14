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
- An **ACM certificate** in `ca-central-1` (only required when `enable_alb=true`) that covers the domain you plan to use for HTTPS. You will supply its ARN to Terraform.
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
2. **Configure Variables**: Review `terraform/variables.tf`. Update at minimum:
   - `enable_alb`: set to `true` if you want the production (paid) architecture with HTTPS through an Application Load Balancer. Leave `false` to stay 100% in the Free Tier.
   - `acm_certificate_arn`: required **only when** `enable_alb=true` – must point to an issued ACM certificate in `ca-central-1`.
   - `availability_zone` / `secondary_availability_zone`: tune if your account has zonal capacity constraints.
   - `vpc_cidr`: change if `10.0.0.0/16` conflicts with existing networks (production mode only).
   - `key_name`: optional – set only if you need SSH access, but remember to also add a security-group rule for port 22.
3. **Initialize Terraform**:  
   - Using makefile: run `make init` to initialize the Terraform backend and provider.  
   - Or manually: `terraform -chdir=terraform init`.
4. **Review and Apply**:  
   - Optionally run `make plan` (or `terraform -chdir=terraform plan`) to review the planned changes.  
   - Deploy the infrastructure with `make apply` (or `terraform -chdir=terraform apply`).  
     - Example free-tier deployment: `terraform -chdir=terraform apply`  
     - Example production deployment: `terraform -chdir=terraform apply -var "enable_alb=true" -var "acm_certificate_arn=arn:aws:acm:ca-central-1:123456789012:certificate/..."` 
5. **Deployment Output**: After apply, Terraform will output the EC2 instance's public IP (always) and, when `enable_alb=true`, the ALB DNS/URL.
6. **Test the Web Server**:  
   - **Free Tier mode** (`enable_alb=false`): open `http://<instance_public_ip>` to reach the Dockerized Nginx directly.  
   - **Production mode** (`enable_alb=true`): copy the `alb_https_url` output (or `alb_dns_name`) and open it in a browser to hit the HTTPS Application Load Balancer.
7. **Optional - GitHub Actions**: The workflow in `.github/workflows/terraform.yml` expects the repository secrets `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` so it can run `terraform plan` against your remote state backend. Add those secrets (with least-privilege IAM credentials) before enabling the workflow.
8. **Cleanup**: When finished, destroy the resources to avoid ongoing charges (though a t2.micro on Free Tier has no cost up to certain usage): run `make destroy` (or `terraform -chdir=terraform destroy`). This will terminate the EC2 instance and remove associated resources. Remember to delete the Terraform state files from the S3 bucket if you are discarding the project.

## How it Works

- **Docker**: The `docker/Dockerfile` is based on the official Nginx image and simply adds a custom `index.html` to replace the default Nginx welcome page. This image is built on the EC2 instance at startup.
- **EC2 User Data**: The EC2 instance is an Amazon Linux 2 server. On launch, Terraform injects the `scripts/user_data.sh` script, which installs Docker, enables it at boot, builds the custom image using the bundled Dockerfile + HTML, and runs the container with a restart policy so it survives reboots.
- **Networking & Load Balancing**: When `enable_alb=true`, Terraform builds a dedicated VPC (two public subnets, route tables, internet gateway) plus an **Application Load Balancer** that terminates HTTPS using your ACM certificate. HTTP automatically redirects to HTTPS. In free-tier mode we simply reuse the default VPC/subnet and expose port 80 directly.
- **Security**:  
  - **Free Tier mode**: A single security group permits inbound HTTP (port 80) from anywhere (to stay simple and within the Free Tier).  
  - **Production mode**: The instance security group only allows traffic from the ALB; nothing is exposed directly to the internet.  
  No SSH access is configured by default; to enable it you must provide a key pair, add a port-22 ingress rule, and ensure IAM/security compliance. The S3 backend ensures state is persisted and shareable if working in a team (remember to update `terraform/backend.tf` with your bucket name and create the bucket ahead of time).
- **Observability**: CloudWatch alarms monitor EC2 CPU usage (all modes) and ALB target health (production mode) to provide early warnings if the container is saturated or failing health checks.

## Architecture Modes & AWS Services

- **Architecture Diagram**

```mermaid
flowchart TD
    subgraph FreeTier["Free Tier Mode (default)"]
        subgraph DefaultVPC["AWS Default VPC"]
            Internet -->|HTTP :80| SGFree[Security Group<br/>Allow HTTP from anywhere]
            SGFree --> EC2Free[EC2 (t2.micro)<br/>Docker + Nginx]
        end
    end

    subgraph Production["Production Mode (`enable_alb=true`)"]
        subgraph VPC["Custom VPC 10.0.0.0/16"]
            IGW[Internet Gateway]
            subgraph PublicSubnets["Public Subnets (AZ A & B)"]
                ALB[Application Load Balancer<br/>HTTPS/ACM]
            end
            subgraph AppSubnet["App Subnet (Primary AZ)"]
                SGApp[Security Group<br/>Only ALB traffic]
                EC2Prod[EC2 (t2.micro)<br/>Docker + Nginx]
            end
        end
        Internet -->|HTTP/HTTPS| ALB
        ALB -->|HTTP :80| SGApp --> EC2Prod
        CloudWatch[(CloudWatch Alarms)]
        EC2Prod -->|CPU Alarm| CloudWatch
        ALB -->|Unhealthy Target Alarm| CloudWatch
        S3[(S3 Backend)]
        TerraformCLI[Terraform CLI] -->|State| S3
    end
```

- **Free Tier mode (default)**  
  - Resources: default VPC/subnet, single `t2.micro` EC2 instance with Docker & Nginx, security group allowing HTTP.  
  - Cost: fits entirely within the AWS Free Tier (assuming <750 instance hours and minimal data transfer).  
  - Usage: `terraform -chdir=terraform apply` (leave `enable_alb` as `false`).

- **Production HTTPS mode (`enable_alb=true`)**  
  - Resources: dedicated VPC, two public subnets, Internet Gateway, Application Load Balancer (HTTP→HTTPS redirect), ACM certificate, per-component security groups, CloudWatch alarms for EC2 CPU and ALB target health.  
  - Cost: incurs ALB hourly + LCU charges (~$1/day) in addition to the EC2 instance.  
  - Usage: `terraform -chdir=terraform apply -var "enable_alb=true" -var "acm_certificate_arn=<your-arn>"`.

**AWS Services Utilized**  
- Amazon EC2 (Amazon Linux 2) hosting Dockerized Nginx.  
- Docker (on EC2) serving the custom HTML page.  
- Amazon VPC + subnets + Internet Gateway (production mode).  
- AWS Application Load Balancer with ACM certificate (production mode).  
- AWS CloudWatch metric alarms (CPU + ALB health).  
- Amazon S3 (Terraform remote state) and optionally DynamoDB for state locking.  
- AWS IAM (implicit via your credentials) to provision the infrastructure.

## Notes

- All components are within Free Tier usage limits (single t2.micro instance, minimal S3 storage for state). Ensure you destroy the resources when not needed.
- You can customize the `index.html` content or other parameters (like region or instance type) by editing the files before deployment.
- If you encounter any issues, make sure your AWS credentials are properly configured and that the AWS region in Terraform variables matches your S3 bucket region for the backend.

## Troubleshooting

- **`terraform init` fails with S3 backend errors**: Confirm the bucket in `terraform/backend.tf` exists in `ca-central-1` and that your IAM user has `s3:ListBucket`, `s3:GetObject`, and `s3:PutObject` permissions for the specified key.
- **ACM certificate errors**: Ensure `acm_certificate_arn` references an **issued** certificate (status: `ISSUED`) in `ca-central-1`. Pending validation or certificates in another region will cause the ALB listener to fail creation (only relevant when `enable_alb=true`).
- **`InvalidKeyPair.NotFound` during apply**: Either remove any non-null `key_name` or create/upload the matching key pair in EC2 before running Terraform.
- **Unable to reach the web server**:  
  - Free Tier mode: verify the instance security group still allows port 80 and the instance passed status checks.  
  - Production mode: confirm the ALB DNS name resolves, security groups allow 80/443 inbound on the ALB, and the instance security group allows traffic from the ALB SG. Use `aws elbv2 describe-target-health` and `aws ec2 describe-instances` to confirm health and status checks.
- **ALB reports unhealthy targets**: Check the CloudWatch alarm `docker-web-alb-unhealthy`, review target descriptions in the EC2 console, and inspect `/var/log/cloud-init-output.log` on the instance to ensure Docker is running and exposing port 80.
- **GitHub Actions workflow fails to plan**: Ensure repo secrets `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set, and that the IAM policy allows `terraform init/plan` operations (EC2 describe, S3 backend access).
- **Docker container stops after reboot**: The provided `scripts/user_data.sh` configures Docker with `systemctl enable` and a `--restart unless-stopped` policy. Re-run `terraform apply` if the script did not finish (check `/var/log/cloud-init-output.log`).

## Roadmap (Prioritized)

1. **Operational automation** – Expand GitHub Actions to run `terraform plan` for every PR and optional `apply` to a staging workspace, then add smoke tests (curl the public endpoint) to prove deployments succeed.
2. **Scalability features** – Introduce auto scaling (ASG or ECS) and integrate a managed data store (RDS/DynamoDB) plus IAM roles to showcase multi-service architecture.
3. **Maintainability & security** – Break Terraform into reusable modules, add policy-as-code checks (tfsec/checkov), and document runbooks/troubleshooting for ongoing support.
4. **Documentation polish** – Produce an architecture diagram, screenshots, and a concise “Key Achievements” section (plus live demo URL if available) to communicate the solution clearly.
