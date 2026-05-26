[← README](../README.md) | [← Prev: Future Work](./07-future-work.md) | **Appendix**

---

# 8. Appendix

## 8.1 Service Inventory

| Layer                  | Service                              | Purpose                                                  |
| ---------------------- | ------------------------------------ | -------------------------------------------------------- |
| DNS                    | Amazon Route 53                      | Alias to CloudFront, health checks                       |
| Certificates           | AWS Certificate Manager              | TLS certs for CloudFront and ALB, auto-rotated           |
| Edge                   | CloudFront, AWS WAF                  | Only public AWS endpoint; caching, DDoS, OWASP rules     |
| Frontend               | Amazon S3 + CloudFront               | Static SPA delivered from S3 via CloudFront (OAC)        |
| End-user identity      | Amazon Cognito User Pool             | Sign-up / sign-in / MFA / JWT issuance                   |
| Transactional email    | Amazon SES                           | Cognito mail, contest invites, verdict notifications     |
| Load balancing         | Application Load Balancer            | L7 routing in front of the orchestrator (judge1); SG locked to CloudFront prefix list |
| Compute (app)          | ECS Fargate                          | Submission orchestrator (judge1)                         |
| Compute (workers)      | ECS on EC2 + ASG                     | `judge0` sandboxed execution                             |
| Container registry     | Amazon ECR                           | Private image registry with scan-on-push                 |
| Operator access        | SSM Session Manager                  | Bastion-free shell, session logging, patching            |
| Networking             | VPC, NAT GW, VPC Endpoints           | Subnet tiers; private connectivity to AWS services       |
| Queue                  | ElastiCache for Redis                | Durable submission queue (BullMQ backing store)          |
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

## 8.2 Queue-Depth Scaling Signal

A small sidecar Lambda runs every minute, reads the "waiting" count from the ElastiCache-backed queue, and publishes it as a custom CloudWatch metric `Judge/Orchestrator/QueueDepth`. The `judge0` ECS service then uses a target-tracking scaling policy on this metric with a target value (e.g., 50 waiting jobs per running task). This is the primary scale signal for surge capacity; a scheduled action provides pre-warm 15 minutes ahead of any known contest start.

---

[← README](../README.md) | [← Prev: Future Work](./07-future-work.md) | **Appendix**
