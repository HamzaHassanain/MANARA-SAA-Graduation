# Competitive Programming Judge — AWS Reference Architecture

> A reference architecture for a competitive programming judge platform on AWS — submission, sandboxed execution, contest-grade scaling, and post-round analytics.

This repository is my graduation submission for the Manara **AWS Solutions Architect – Associate** course. It is structured as a complete reference architecture: every service is justified, every decision has an alternative considered and rejected, and the whole design maps cleanly to the six pillars of the AWS Well-Architected Framework.

---

## Executive Summary

A competitive programming judge has an unusual operational profile: idle for long stretches, then a contest start produces thousands of submissions per minute against an otherwise quiet platform — each submission running untrusted code in a kernel-level sandbox. The architecture has to handle all four of (a) bursty, scheduled traffic, (b) sandboxed execution of arbitrary code, (c) multi-tenant moderator workflows, and (d) post-round analytics on every submission.

This design composes AWS primitives around two well-known building blocks: [**Judge0**](https://judge0.com/) (the open-source sandbox executor) for code execution, and a stateless **orchestrator** service for submission lifecycle. The frontend is a full Next.js application deployed in the **OpenNext** shape — CloudFront fronting a Lambda Server Function, an Image Optimization Lambda, S3 for static assets, DynamoDB for the ISR tag cache, and SQS for background revalidation. The data tier is **DocumentDB** (Mongo-compatible app data), **ElastiCache for Redis** (durable submission queue), **RDS PostgreSQL** (judge0 internal state), and **S3** (test cases + submissions, partitioned by problem and contest). The post-round cheating-detection pipeline runs on **Step Functions** orchestrating **AWS Batch** (plagiarism), **Lambda + Bedrock** (LLM-generated code detection), and **Athena** (behavioral signals).

The architectural pivot point is the choice of compute for the workers: `judge0` requires privileged container capabilities for `isolate`, which Fargate does not allow — so workers run on **ECS-on-EC2 with autoscaling**, while the stateless orchestrator runs on **Fargate**. Surge capacity comes from Spot in a mixed-instance ASG, driven by a custom CloudWatch metric measuring queue depth.

---

## Hero Architecture — Request Lifecycle

![Request Lifecycle](./drawings/Request-Lifecycle.jpg)

Three companion views (identity, monitoring, security/backup) and the full component breakdown live in [docs/02-architecture.md](./docs/02-architecture.md).

---

## Table of Contents

| # | Document | What's in it |
|---|----------|--------------|
| 1 | [Requirements](./docs/01-requirements.md) | Functional + non-functional requirements; explicit out-of-scope |
| 2 | [Architecture](./docs/02-architecture.md) | Four architectural views + component-by-component breakdown |
| 3 | [Cheating Detection Pipeline](./docs/03-cheating-detection.md) | Post-round Step Functions / Batch / Bedrock pipeline |
| 4 | [Design Decisions](./docs/04-design-decisions.md) | Eight architectural choices with options, rationale, alternatives |
| 5 | [Well-Architected Mapping](./docs/05-well-architected.md) | Mapping to the six AWS WAFR pillars |
| 6 | [Risks & Mitigations](./docs/06-risks.md) | RTO/RPO targets + risk register |
| 7 | [Future Work](./docs/07-future-work.md) | Improvements queued for v2 |
| 8 | [Appendix](./docs/08-appendix.md) | Service inventory + queue-depth scaling signal |

---

## Repository Layout

```
.
├── README.md                          ← this file — overview, hero diagram, TOC
├── AWS SAA Project Submission.pdf     ← single-PDF export of the docs (for offline review)
├── docs/                              ← detailed sections, each a standalone page
│   ├── 01-requirements.md
│   ├── 02-architecture.md
│   ├── 03-cheating-detection.md
│   ├── 04-design-decisions.md
│   ├── 05-well-architected.md
│   ├── 06-risks.md
│   ├── 07-future-work.md
│   └── 08-appendix.md
└── drawings/                          ← exported PNG/SVG versions of the architecture diagrams (Mermaid → image)
```

Each doc file carries `← Prev | Next →` navigation at top and bottom, so you can read straight through or jump in.
