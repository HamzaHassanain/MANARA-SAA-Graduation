[← README](../README.md) | [← Prev: Well-Architected](./07-well-architected.md) | **Risks & Mitigations** | [Next: Future Work →](./09-future-work.md)

---

# 8. Risks and Mitigations

## 8.1 RTO / RPO Targets

| Component                       | RTO          | RPO       | Mechanism                                                            |
| ------------------------------- | ------------ | --------- | -------------------------------------------------------------------- |
| `judge1` (Fargate)              | < 5 min      | n/a       | Stateless; ECS service replaces failed tasks                         |
| `judge0` (ECS-on-EC2)           | < 10 min     | n/a       | ASG replaces hosts; in-flight batches re-queued by BullMQ            |
| ElastiCache for Redis           | < 5 min      | < 1 min   | Multi-AZ automatic failover to replica                               |
| RDS PostgreSQL                  | < 5 min      | < 1 min   | Multi-AZ automatic failover + 35-day PITR                            |
| Amazon DocumentDB               | < 5 min      | < 1 min   | Replica-set promotion within the cluster                             |
| S3 (testcases, submissions)     | n/a          | 0         | 11 nines durability, versioning enabled                              |
| Full single-region failure      | Hours        | Hours     | Accepted for v1; Pilot Light path described in [Future Work](./09-future-work.md) |

## 8.2 Risk Register

**DocumentDB feature gap.** Risk: an unsupported MongoDB feature is in production use and the migration cannot proceed. Mitigation: explicit audit in Phase 4 pre-work; defined fallback to MongoDB Atlas with the same migration mechanics.

**`isolate` version skew between DO and AWS.** Risk: a submission that compiles or runs on DO fails on AWS due to subtle sandbox-version differences. Mitigation: 10,000-submission shadow comparison in Phase 3 specifically targets this class of bug.

**Bedrock cost surprise on a high-volume round.** Risk: a viral round produces 100K submissions and the LLM-detection bill spikes. Mitigation: per-round cost budget alarm; fall back to sampling (random subset + always-evaluate-AC subset) when budget is exceeded.

**Spot interruption during a contest.** Risk: Spot fleet termination during a round causes verdict delays. Mitigation: On-Demand baseline absorbs interruptions; `judge1`'s timeout-and-retry re-queues in-flight batches; capacity-optimized Spot allocation strategy reduces interruption rate.

**Single-region failure.** Risk: a region-wide AWS event takes us offline. Mitigation: accepted risk for v1, given our user base. Future work to add cross-region async replication of S3 buckets and DocumentDB snapshots for a "warm cold" DR posture (RTO measured in hours, not minutes).

---

[← README](../README.md) | [← Prev: Well-Architected](./07-well-architected.md) | **Risks & Mitigations** | [Next: Future Work →](./09-future-work.md)
