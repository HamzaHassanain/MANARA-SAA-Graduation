[← README](../README.md) | [← Prev: Migration Plan](./06-migration-plan.md) | **Well-Architected** | [Next: Risks →](./08-risks.md)

---

# 7. Well-Architected Framework Mapping

**Operational Excellence.** All infrastructure as code (CloudFormation or Terraform). Centralized logging in CloudWatch. Distributed tracing in X-Ray. Runbooks for failover and rollback at each migration phase. Step Functions execution history provides full auditability for the cheating-detection pipeline.

**Security.** Defense-in-depth: WAF at the edge, ALB in public subnet only, all compute and data in private subnets, security groups with least-privilege rules, IAM task roles scoped per service, Secrets Manager for credentials with rotation, KMS CMKs for all data at rest, CloudTrail across the account, GuardDuty for threat detection, S3 bucket policies that deny non-TLS access.

**Reliability.** Multi-AZ for every stateful service (RDS, DocumentDB, ElastiCache). ASG ensures `judge0` workers self-heal. ECS service definitions ensure `judge1` tasks self-heal. SQS-style retry semantics in BullMQ handle transient `judge0` failures. Health checks at the ALB and Route 53 ensure unhealthy targets are removed from rotation. **AWS Backup** runs a centralized backup plan: daily RDS and DocumentDB snapshots with 35-day retention, plus point-in-time-recovery on RDS; S3 versioning on the `testcases` and `submissions` buckets provides per-object rollback. Phased migration with rollback at each step.

**Performance Efficiency.** Right-sized compute per workload (Fargate for stateless `judge1`, EC2 for sandboxed `judge0`). Auto-scaling driven by the most relevant signal (queue depth, not CPU). S3 + CloudFront-ready test case delivery. DocumentDB read replicas for verdict-fetch traffic. X-Ray to identify and remove latency hotspots.

**Cost Optimization.** Spot for `judge0` surge. Scale-to-near-zero between contests (baseline of 1–2 instances). S3 Intelligent-Tiering for cold testcases. Scheduled scaling kills idle capacity outside contest windows. Bedrock pay-per-invocation matches the bursty, post-round inference workload.

**Sustainability.** Scale-to-near-zero between contests directly reduces idle energy use. Spot is filling otherwise-wasted capacity. Single-region is appropriate for our user distribution and avoids over-provisioning.

---

[← README](../README.md) | [← Prev: Migration Plan](./06-migration-plan.md) | **Well-Architected** | [Next: Risks →](./08-risks.md)
