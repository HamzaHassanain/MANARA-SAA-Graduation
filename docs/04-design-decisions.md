[← README](../README.md) | [← Prev: Post-Round Processing](./03-post-round-processing.md) | **Design Decisions** | [Next: Well-Architected →](./05-well-architected.md)

---

# 4. Key Design Decisions

These are the architectural decisions where a defensible choice matters more than the choice itself. Each is documented with options, choice, and rationale — the form an SAA exam item would test.

**4.1 Fargate vs ECS-on-EC2 for `judge0` workers.**
Options: Fargate, ECS-on-EC2, EKS, raw EC2 ASG.
Choice: **ECS-on-EC2.**
Rationale: `judge0` requires the `isolate` sandbox, which needs cgroups and privileged container capabilities. Fargate does not allow privileged mode, ruling it out. EKS would work but adds an operational layer not needed at this scale. Raw EC2 ASG would work but ECS gives declarative task definitions and rolling deploys for free. The orchestrator (judge1) service has no such constraint and runs on Fargate.

**4.2 Amazon DocumentDB vs MongoDB Atlas on AWS.**
Options: DocumentDB, MongoDB Atlas (AWS-hosted), self-hosted MongoDB on EC2.
Choice: **DocumentDB**, with Atlas as a defined fallback.
Rationale: DocumentDB is MongoDB-compatible up to a specific API version and integrates natively with the rest of the AWS account (IAM, VPC, KMS, CloudWatch). Atlas is a more capable database with full MongoDB feature parity, but it is a separate vendor relationship, separate IAM, separate billing. **Decision gate**: if the application depends on Mongo features past DocumentDB's compatibility version (transactions across collections, change streams with complex filters, advanced aggregation operators), switch to Atlas. Self-hosting is rejected — the explicit theme of this architecture is exiting the "manage our own database" business.

**4.3 Spot vs On-Demand for `judge0` workers.**
Options: 100% On-Demand, mixed (On-Demand baseline + Spot for surge), 100% Spot.
Choice: **Mixed.** On-Demand for the steady baseline (1–2 instances), Spot for surge during contests.
Rationale: A killed `judge0` worker has a self-healing failure mode — the in-flight batch is simply re-queued by the orchestrator's (judge1) timeout-and-retry logic — so Spot's interruption risk is tolerable. Cost savings are typically 50–70%. Keeping a small On-Demand baseline prevents Spot capacity unavailability from breaking idle-period traffic.

**4.4 Polling vs webhooks for `judge0` completion.**
Options: Poll `judge0` for batch completion, register `judge0` callbacks to an HTTPS endpoint.
Choice: **Poll in v1; webhooks in v2.**
Rationale: Polling is well-understood and decoupled from the orchestrator's (judge1) reachability — a webhook receiver introduces a new public-or-VPC-internal endpoint and an extra failure mode. Once the platform is stable, replacing the poll loop with callbacks to an API Gateway endpoint would reduce latency and load on the queue — flagged in [Future Work](./07-future-work.md).

**4.5 Bedrock vs SageMaker for LLM-generated code detection.**
Options: Amazon Bedrock (fully managed FM inference), SageMaker real-time endpoint, SageMaker batch transform.
Choice: **Bedrock for v1, batch transform for scale.**
Rationale: Bedrock removes model hosting from the operational burden entirely and allows iteration on the prompt and grader without retraining. Per-inference cost is higher than a self-hosted classifier, but at the post-round, batch-able volume assumed here, this is acceptable. The path to SageMaker batch transform (using a fine-tuned model trained on moderator-labeled examples) is clean and warranted only if Bedrock costs cross a predefined threshold.

**4.6 Real-time vs post-round cheating detection.**
Options: Block at submission time, flag at submission time, flag post-round.
Choice: **Flag post-round.**
Rationale: Real-time blocking has unacceptable false-positive risk (an honest submission that resembles a known cheating pattern would be denied AC). Real-time flagging adds latency to the verdict path. Post-round runs on the full submission set in batch, supports more expensive signals (pairwise N² plagiarism), and gives moderators a curated queue rather than an alert stream.

**4.7 Identity provider — Cognito vs Auth0 vs self-managed.**
Options: Amazon Cognito User Pool, Auth0 (or another SaaS IdP), self-managed JWT inside the orchestrator (judge1).
Choice: **Cognito User Pool.**
Rationale: Cognito gives sign-up, sign-in, hosted UI, MFA, password reset, and JWKS-validated JWTs without any code to maintain, and integrates natively with ALB (auth action), API Gateway (Cognito authorizer), and SES (verification emails). The free tier covers the first 50K monthly active users, comfortably more than the assumed scale. Auth0 is more feature-rich (enterprise SSO, fine-grained RBAC UI) but introduces a separate vendor relationship and billing line — overkill for a contest platform. Self-managed JWT is rejected: rolling password reset, MFA, and rate-limited login flows from scratch is exactly the kind of work AWS has already solved.

**4.8 Static SPA on S3+CloudFront vs server-rendered web app.**
Options: static SPA delivered from S3+CloudFront with all dynamic behaviour handled by the orchestrator (judge1) API, vs a server-rendered app running on Lambda (per-request rendering) or ECS Fargate (long-lived Node server).
Choice: **Static SPA on S3+CloudFront.**
Rationale: A contest judge's frontend is fundamentally a thin client over the orchestrator (judge1) API — submission forms, leaderboard polling, verdict displays. None of that needs server-side rendering for SEO (auth-gated content) or for initial paint (the user is signed in and on a warm CDN edge). Static delivery from S3 through CloudFront gives global low-latency reads, near-zero idle cost, no cold-start tier in the request path, and a smaller attack surface (no compute means no SSRF, no server-side dependency CVEs). Server-rendered alternatives add a compute tier — Lambda (cold starts plus per-request billing) or Fargate (always-on cost between contests) — that the workload does not justify. Dynamic interactions go straight from the browser to the orchestrator (judge1) via the CloudFront `/api/*` behavior, so a single distribution covers both static assets and API traffic uniformly under WAF.

**4.9 Live standings — incremental Redis ZSET vs periodic full recompute vs per-event DocumentDB row update.**
Options: (a) every minute, a Lambda recomputes the whole leaderboard from the submissions collection and writes a materialized view; (b) on every accepted verdict, the orchestrator (judge1) updates one row in DocumentDB and clients poll a `/standings` endpoint; (c) on every accepted verdict, the orchestrator (judge1) does a single `ZADD` into an ElastiCache **Redis sorted set** keyed per contest, and a publisher service fans deltas out to clients over WebSocket plus a CloudFront-cached top-100 snapshot.
Choice: **(c) incremental ZSET + WebSocket + CloudFront-cached snapshot.**
Rationale: at 40K concurrent standings readers and ~1–2K submissions/sec at peak, option (a) wastes ~240K document reads per minute on data that has not changed and is one full minute behind real-time. Option (b) sends ~40K poll requests every few seconds straight to the database, with each poll requiring a sort over the whole contest collection — DocumentDB is not built for this read shape. Option (c) is the design Codeforces actually uses in spirit: rank computation lives in a structure that supports O(log N) inserts and O(log N + k) range reads, the database is touched only on writes (and only to update one row), and the read fanout problem is solved by the CDN — 39,900 of the 40K viewers get the public top-100 from a CloudFront edge cache, while the ~100 personally-affected users per second receive a targeted WebSocket delta. The cost shape is also linear in submissions, not in standings readers, which is the right shape for a workload that scales horizontally on submissions and vertically on viewers.

---

[← README](../README.md) | [← Prev: Post-Round Processing](./03-post-round-processing.md) | **Design Decisions** | [Next: Well-Architected →](./05-well-architected.md)
