[← README](../README.md) | [← Prev: Well-Architected](./05-well-architected.md) | **Risks & Mitigations** | [Next: Future Work →](./07-future-work.md)

---

# 6. Risks and Mitigations

## 6.1 RTO / RPO Targets

| Component                       | RTO          | RPO       | Mechanism                                                            |
| ------------------------------- | ------------ | --------- | -------------------------------------------------------------------- |
| Orchestrator (judge1, Fargate)  | < 5 min      | n/a       | Stateless; ECS service replaces failed tasks                         |
| `judge0` (ECS-on-EC2)           | < 10 min     | n/a       | ASG replaces hosts; in-flight batches re-queued by the durable queue |
| ElastiCache for Redis           | < 5 min      | < 1 min   | Multi-AZ automatic failover to replica                               |
| RDS PostgreSQL                  | < 5 min      | < 1 min   | Multi-AZ automatic failover + 35-day PITR                            |
| Amazon DocumentDB               | < 5 min      | < 1 min   | Replica-set promotion within the cluster                             |
| S3 (testcases, submissions)     | n/a          | 0         | 11 nines durability, versioning enabled                              |
| Full single-region failure      | Hours        | Hours     | Accepted for v1; Pilot Light path described in [Future Work](./07-future-work.md) |

## 6.2 Risk Register

**DocumentDB feature gap.** Risk: an application code path depends on a MongoDB feature past DocumentDB's compatibility version (cross-collection transactions, change-stream filter complexity, advanced aggregation operators). Mitigation: explicit pre-launch audit of the data-access layer against the DocumentDB compatibility matrix; defined fallback to MongoDB Atlas with the same wire protocol so application code does not change.

**Bedrock cost surprise on a high-volume round.** Risk: a viral round produces 100K submissions and the LLM-detection bill spikes. Mitigation: per-round cost budget alarm; fall back to sampling (random subset + always-evaluate-AC subset) when budget is exceeded.

**Spot interruption during a contest.** Risk: Spot fleet termination during a round causes verdict delays. Mitigation: On-Demand baseline absorbs interruptions; the orchestrator's (judge1) timeout-and-retry re-queues in-flight batches; capacity-optimized Spot allocation strategy reduces interruption rate.

**Untrusted code escape from the sandbox.** Risk: a 0-day in `isolate` or the host kernel allows user code to break out of the sandbox. Mitigation: `judge0` hosts run in a dedicated private subnet with **no egress to the public internet** (no NAT route, no IGW path) and no IAM credentials beyond what is strictly required for ECS task lifecycle; outbound AWS-service access is through VPC endpoints only; GuardDuty Runtime Monitoring on the EC2 hosts catches anomalous syscalls.

**Single-region failure.** Risk: a region-wide AWS event takes the platform offline. Mitigation: accepted risk for v1. Future work to add cross-region async replication of S3 buckets and DocumentDB snapshots for a "warm cold" DR posture (RTO measured in hours, not minutes).

---

[← README](../README.md) | [← Prev: Well-Architected](./05-well-architected.md) | **Risks & Mitigations** | [Next: Future Work →](./07-future-work.md)
