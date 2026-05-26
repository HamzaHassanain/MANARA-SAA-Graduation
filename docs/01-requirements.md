[← README](../README.md) | **Requirements** | [Next: Architecture →](./02-architecture.md)

---

# 1. Requirements

This is a reference architecture for a **competitive programming judge platform** on AWS — a web application that accepts code submissions, executes them against problem test cases in a hardened sandbox, returns a verdict, and supports the operational realities of timed contests (bursty traffic, strict latency, untrusted user code, moderator workflows). It is greenfield: nothing in this design is constrained by a prior production system.

## 1.1 Functional Requirements

- **Code submission and judging.** Users submit source code for a problem; the platform compiles it, runs it against the problem's test cases under CPU and memory limits, and returns a per-test-case verdict (Accepted / Wrong Answer / TLE / MLE / RE / CE).
- **Contests.** Time-bounded windows with a known participant count, after which submissions stop and a final leaderboard is published.
- **Problem and test-case management.** Admins create problems and upload large, immutable test-case payloads (input + expected output). Test cases are loaded by the judge at submission time.
- **Identity.** Sign-up, sign-in, password reset, email verification, optional MFA, and role-based access for users / moderators / admins.
- **Moderator review.** Moderators triage flagged submissions (plagiarism, suspected LLM-generated code) post-round.

## 1.2 Non-Functional Requirements

- **Burst traffic.** A contest start can produce thousands of submissions per minute against an otherwise idle platform. The architecture must scale up on schedule and on demand.
- **Untrusted code execution.** User code runs in a kernel-level sandbox (`isolate` / cgroups). The sandbox host must never be reachable from the public internet.
- **Multi-AZ availability.** Every stateful component spans at least two Availability Zones with automatic failover.
- **Observability.** Distributed tracing across the full submission path; a synthetic submit-and-poll canary as the source-of-truth liveness signal.
- **Security.** Defence-in-depth: WAF at the edge, private subnets for all compute and data, least-privilege IAM task roles, KMS-encrypted storage, Secrets Manager with rotation, GuardDuty + Security Hub for threat detection.

## 1.3 Out of Scope

- **Multi-region active-active.** Single region with Multi-AZ is the right target for the user base assumed here. A Pilot Light cross-region DR path is enumerated in [Future Work](./07-future-work.md).
- **Real-time cheating detection.** Per-submission ML signals add verdict latency and have unacceptable false-positive risk. The architecture provides **post-round** analytics instead.
- **Replacing the sandbox executor.** The architecture builds on top of [Judge0](https://judge0.com/) — a battle-tested open-source code-execution sandbox. Replacing it with a custom executor is explicitly not in scope.

---

[← README](../README.md) | **Requirements** | [Next: Architecture →](./02-architecture.md)
