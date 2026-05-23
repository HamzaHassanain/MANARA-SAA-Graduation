[← README](../README.md) | [← Prev: Future Work](./09-future-work.md) | **Appendix**

---

# 10. Appendix

## 10.1 Service Inventory

| Layer                  | Service                              | Purpose                                                  |
| ---------------------- | ------------------------------------ | -------------------------------------------------------- |
| DNS                    | Amazon Route 53                      | Alias to CloudFront, health checks                       |
| Certificates           | AWS Certificate Manager              | TLS certs for CloudFront and ALB, auto-rotated           |
| Edge                   | CloudFront, AWS WAF                  | Only public AWS endpoint; caching, DDoS, OWASP rules     |
| Frontend — static      | Amazon S3                            | Next.js build output, prerendered HTML, `public/`        |
| Frontend — server      | AWS Lambda (Server Function URL)     | Next.js SSR + RSC + API routes + Server Actions          |
| Frontend — images      | AWS Lambda (Image Optimization)      | `/_next/image` on-the-fly resizing                       |
| Frontend — ISR cache   | Amazon DynamoDB                      | Next.js cache tags + per-route revalidation metadata     |
| Frontend — revalidate  | Amazon SQS                           | Background ISR revalidation queue                        |
| End-user identity      | Amazon Cognito User Pool             | Sign-up / sign-in / MFA / JWT issuance                   |
| Transactional email    | Amazon SES                           | Cognito mail, contest invites, verdict notifications     |
| Load balancing         | Internal ALB                         | VPC-internal L7 routing in front of `judge1` (no public ALB) |
| Compute (app)          | ECS Fargate                          | `judge1` orchestration layer                             |
| Compute (workers)      | ECS on EC2 + ASG                     | `judge0` sandboxed execution                             |
| Container registry     | Amazon ECR                           | Private image registry with scan-on-push                 |
| Operator access        | SSM Session Manager                  | Bastion-free shell, session logging, patching            |
| Networking             | VPC, NAT GW, VPC Endpoints           | Subnet tiers; private connectivity to AWS services       |
| Queue                  | ElastiCache for Redis                | BullMQ backing store                                     |
| Database (app)         | Amazon DocumentDB                    | Mongo-compatible app data                                |
| Database (job state)   | RDS PostgreSQL                       | `judge0` internal state                                  |
| Object storage         | Amazon S3                            | Test cases, submissions, analytics, logs                 |
| Backups                | AWS Backup                           | Centralized backup plans for RDS, DocDB, EBS             |
| Orchestration          | AWS Step Functions                   | Cheating-detection pipeline                              |
| Batch compute          | AWS Batch                            | Plagiarism N² jobs                                       |
| Analytics              | AWS Glue, Amazon Athena              | Behavioral signal queries                                |
| ML inference           | Amazon Bedrock                       | LLM-generated code detection                             |
| Workload identity      | AWS IAM                              | Roles, policies, boundaries (services, not end users)    |
| Secrets                | AWS Secrets Manager                  | DB credentials with rotation                             |
| Encryption             | AWS KMS                              | Customer-managed keys                                    |
| Logs (streaming)       | CloudWatch Logs                      | Per-service log groups; 30d app / 365d audit             |
| Logs (long-retention)  | S3 logs bucket                       | ALB / CloudFront / VPC Flow / CloudTrail; Object Lock    |
| Metrics & tracing      | CloudWatch Metrics, X-Ray            | Container Insights, custom QueueDepth, service map       |
| Synthetic monitoring   | CloudWatch Synthetics                | Submit-and-poll canary every 5 minutes                   |
| Threat detection       | GuardDuty, CloudTrail                | Threat findings, account-wide audit log                  |
| Compliance             | AWS Config, Security Hub             | Resource state, CIS benchmark, finding aggregation       |
| Eventing               | Amazon EventBridge                   | Round-ended trigger                                      |
| Notification           | Amazon SNS                           | `ops-critical` / `ops-warning` + moderator alerts        |

## 10.2 Sample BullMQ-Queue-Depth Scaling Signal

A small sidecar Lambda runs every minute, reads the BullMQ "waiting" count from ElastiCache, and publishes it as a custom CloudWatch metric `Repovive/judge1/QueueDepth`. The `judge0` ECS service then uses a target-tracking scaling policy on this metric with a target value (e.g., 50 waiting jobs per running task). This replaces the manual 3-click scale-up entirely.

---

[← README](../README.md) | [← Prev: Future Work](./09-future-work.md) | **Appendix**
