# Development Notes

This document captures the major decisions, challenges, and forward-looking plans encountered while building the **Docker Web Server Terraform** project.

## Timeline & Key Challenges

1. **Initial Infrastructure Bootstrap**
   - Goal: provision a Free-Tier friendly EC2 instance with Docker + Nginx via Terraform.
   - Challenge: the project originally relied on the default VPC without a fully defined backend. We standardized on an S3 backend and documented the requirement to pre-create the bucket.

2. **Docker & User Data Reliability**
   - Early revisions simply ran the stock `nginx` container without persisting changes. We switched to a custom Dockerfile + `user_data` script that builds and runs the container with a restart policy so the site survives restarts.
   - Ensured Docker is enabled as a service and that the script removes/recreates the container idempotently.

3. **Security Posture**
   - SSH access was unintentionally open to the world. We aligned the configuration with the README by removing the default port-22 rule and making the key pair optional.
   - Documented the steps required if administrators need SSH access in the future (supply `key_name` + add ingress rule).

4. **CI/CD Integration**
   - Added GitHub Actions to run `terraform init/validate/plan`. The main hurdle was credential management, so we now require repository secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) and least-privilege IAM policies.

5. **State Management Hygiene**
   - Removed accidentally committed `.terraform` artifacts and established a backup process before major edits to avoid drift.

6. **Availability Zone Capacity**
   - Encountered an AWS error where `t2.micro` was unavailable in `ca-central-1d`. Mitigated by introducing a configurable `availability_zone` variable and filtering subnets to match, defaulting to `ca-central-1a`.

7. **Developer Tooling Gaps**
   - Some contributors lacked GNU Make (common on Windows), so we documented that it is optional and provided installation guidance plus raw Terraform command equivalents.

8. **Production Networking & Observability**
   - Implemented a dedicated VPC, dual public subnets, and an Application Load Balancer terminating HTTPS with ACM.
   - Locked down security groups (ALB-only ingress) and added CloudWatch alarms for EC2 CPU saturation and ALB target health.
   - Added the `enable_alb` flag so users can switch between a Free-Tier friendly setup and the paid production-grade stack.

## Lessons Learned

- **Documentation drift happens quickly**: keeping README instructions aligned with Terraform defaults prevents confusion (e.g., Free-Tier instance type, SSH defaults, backend requirements).
- **Idempotent bootstrapping is critical**: user-data scripts should tolerate reruns and leave the system in a known-good state.
- **Security defaults matter**: it's safer to start closed (port 80 only, optional SSH) and let operators opt in to additional access patterns.
- **CI needs credentials**: automations should explicitly require secrets instead of assuming developers have local profiles.
- **Regional resources have constraints**: services like ACM issue certificates per-region and ALBs require subnets across AZs, so infrastructure defaults must account for those limitations.
- **Cost-aware toggles help adoption**: exposing a simple variable (`enable_alb`) lets users choose between free experimentation and production-grade features without editing code.

## Roadmap & Future Enhancements

- Offer optional Session Manager access or bastion-host module for SSH-less administration.
- Parameterize backend configuration through partial `backend.hcl` files to support multiple environments.
- Add automated smoke tests (curl checks) after Terraform `apply` in non-production accounts.
- Integrate CloudWatch metrics/log forwarding and alarms for EC2 health and Docker status.
- Provide Terraform modules for reusable components (security groups, EC2 profiles) to make scaling easier.

Refer back to `README.md` for user-facing instructions and the latest troubleshooting guidance. This file is meant for contributors who want deeper insight into the project’s evolution and upcoming work.
