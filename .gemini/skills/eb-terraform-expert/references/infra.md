# AWS Infrastructure Details

## Architecture Overview

### 1. S3 Website Hosting
- **Bucket Purpose**: Host the static Flutter web application.
- **Access Control**: Publicly accessible for website hosting.

### 2. CloudFront CDN
- **Origin**: S3 bucket website endpoint.
- **Cache Policy**: Optimized for single-page applications (SPAs).
- **SSL**: Uses AWS Certificate Manager (ACM) if configured.

## Terraform Setup

- **State Management**: Local state by default (can be moved to S3 backend).
- **Providers**: `aws` provider (configured in `provider.tf`).
- **Variables**: Define region, bucket name, etc., in `variables.tf`.
- **Outputs**: Run `terraform output` to retrieve endpoints after deployment.

## Deployment Workflow
1. Build the Flutter application: `flutter build web`.
2. Synchronize the `build/web/` directory with the S3 bucket: `aws s3 sync build/web/ s3://<bucket-name>`.
3. Invalidate the CloudFront cache if necessary: `aws cloudfront create-invalidation --distribution-id <id> --paths "/*"`.
