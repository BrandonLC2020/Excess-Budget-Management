---
name: eb-terraform-expert
description: Expert in Terraform infrastructure development for the Excess-Budget-Management project. Use when working on AWS resources, S3 (hosting), CloudFront (CDN), and other infrastructure components.
---

# EB Terraform Expert

This skill provides specialized guidance for managing the AWS infrastructure of the Excess-Budget-Management application using Terraform.

## Infrastructure Overview

The project uses Terraform to provision and manage AWS resources for hosting the Flutter web application.

- `infra/s3.tf`: Configuration for the S3 bucket used for hosting.
- `infra/cloudfront.tf`: CloudFront CDN configuration for global distribution.
- `infra/variables.tf`: Configuration variables.
- `infra/outputs.tf`: Resource outputs (e.g., CloudFront URL).

## Technical Stack

- **Cloud Provider**: AWS.
- **Hosting**: S3 Static Website Hosting.
- **CDN**: Amazon CloudFront.
- **Provisioning Tool**: Terraform.

## Workflows

### 1. Modifying the Infrastructure
1. Edit the relevant `.tf` files in the `infra/` directory.
2. Initialize Terraform if needed: `terraform init`.
3. Preview changes with `terraform plan`.
4. Apply changes with `terraform apply`.

### 2. Updating AWS Resources
When adding new AWS services (e.g., RDS or Cognito), follow the existing modular structure and use the variables for configurability.

## Reference Materials

- [Infrastructure](references/infra.md): Details about the AWS architecture and Terraform setup.
