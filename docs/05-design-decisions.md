[← README](../README.md) | [← Prev: Cheating Detection](./04-cheating-detection.md) | **Design Decisions** | [Next: Migration Plan →](./06-migration-plan.md)

---

# 5. Key Design Decisions

These are the architectural decisions where a defensible choice matters more than the choice itself. Each is documented with options, choice, and rationale — the form an SAA exam item would test.

**5.1 Fargate vs ECS-on-EC2 for `judge0` workers.**
Options: Fargate, ECS-on-EC2, EKS, raw EC2 ASG.
Choice: **ECS-on-EC2.**
Rationale: `judge0` requires the `isolate` sandbox, which needs cgroups and privileged container capabilities. Fargate does not allow privileged mode, ruling it out. EKS would work but adds an operational layer we don't need at our scale. Raw EC2 ASG would work but ECS gives us declarative task definitions and rolling deploys for free. `judge1` itself has no such constraint and runs on Fargate.

**5.2 Amazon DocumentDB vs MongoDB Atlas on AWS.**
Options: DocumentDB, MongoDB Atlas (AWS-hosted), self-hosted MongoDB on EC2.
Choice: **DocumentDB initially**, with Atlas as a defined fallback.
Rationale: DocumentDB is MongoDB-compatible up to a specific API version and integrates natively with the rest of the AWS account (IAM, VPC, KMS, CloudWatch). Atlas is a more capable database with full MongoDB feature parity, but it is a separate vendor relationship, separate IAM, separate billing. **Verification action**: before committing, audit current MongoDB usage for transactions, change streams beyond simple watches, and any feature past DocumentDB's compatibility version. If anything blocks, switch to Atlas. Self-hosting is rejected — we are explicitly trying to _exit_ the "manage our own database" business.

**5.3 Spot vs On-Demand for `judge0` workers.**
Options: 100% On-Demand, mixed (On-Demand baseline + Spot for surge), 100% Spot.
Choice: **Mixed.** On-Demand for the steady baseline (1–2 instances), Spot for surge during contests.
Rationale: A killed `judge0` worker has a self-healing failure mode — the in-flight batch is simply re-queued by `judge1`'s timeout-and-retry logic — so Spot's interruption risk is tolerable. Cost savings are typically 50–70%. Keeping a small On-Demand baseline prevents Spot capacity unavailability from breaking idle-period traffic.

**5.4 Polling vs webhooks for `judge0` completion.**
Options: Keep polling, switch to `judge0` webhooks.
Choice: **Keep polling for the migration; revisit later.**
Rationale: Polling works today, it is well-understood, and changing it during a platform migration introduces unnecessary risk. Once stable on AWS, replacing the poll loop with `judge0` callbacks to an API Gateway endpoint would reduce latency and load on the BullMQ queue — flagged as future work.

**5.5 Bedrock vs SageMaker for LLM-generated code detection.**
Options: Amazon Bedrock (fully managed FM inference), SageMaker real-time endpoint, SageMaker batch transform.
Choice: **Bedrock for the first version, batch transform for scale.**
Rationale: Bedrock removes model hosting from the operational burden entirely and lets us iterate on the prompt and grader without retraining. Per-inference cost is higher than a self-hosted classifier, but at our submission volume (post-round, batch-able), this is acceptable for v1. The migration path to SageMaker batch transform (using a fine-tuned model trained on moderator-labeled examples) is clean and warranted only if Bedrock costs cross a threshold we define in advance.

**5.6 Real-time vs post-round cheating detection.**
Options: Block at submission time, flag at submission time, flag post-round.
Choice: **Flag post-round.**
Rationale: Real-time blocking has unacceptable false-positive risk (an honest submission that resembles a known cheating pattern would be denied AC). Real-time flagging adds latency to the verdict path. Post-round runs on the full submission set in batch, supports more expensive signals (pairwise N² plagiarism), and gives moderators a curated queue rather than an alert stream.

**5.7 Identity provider — Cognito vs Auth0 vs self-managed.**
Options: Amazon Cognito User Pool, Auth0 (or another SaaS IdP), self-managed JWT in `judge1` (today's design).
Choice: **Cognito User Pool.**
Rationale: Cognito gives sign-up, sign-in, hosted UI, MFA, password reset, and JWKS-validated JWTs without any code we have to maintain, and integrates natively with ALB (auth action), API Gateway (Cognito authorizer), and SES (verification emails). The free tier covers our first 50K monthly active users, which exceeds current and near-term scale. Auth0 is more feature-rich (enterprise SSO, fine-grained RBAC UI) but introduces a separate vendor relationship and billing line — overkill for a contest platform. Self-managed JWT is rejected: the migration's explicit theme is exiting the "manage our own X" business, and rolling password reset, MFA, and rate-limited login flows from scratch is exactly the kind of work AWS has already solved.

**5.8 Web frontend hosting — S3+CloudFront vs Fargate SSR.**
Options: Static SPA on S3 + CloudFront (with `/api/*` proxied to ALB), or Next.js SSR on a separate Fargate service.
Choice: **Static SPA on S3 + CloudFront.**
Rationale: The frontend is highly cacheable and largely client-rendered (the contest dashboard and editor are interactive but driven by judge1 API calls). Static hosting on S3 + CloudFront gives global edge delivery, zero idle compute cost, and removes a deployment target. SSR on Fargate would add cost and an extra deploy pipeline for marginal benefit. Per-page SEO is a non-goal for an authenticated contest platform.

---

[← README](../README.md) | [← Prev: Cheating Detection](./04-cheating-detection.md) | **Design Decisions** | [Next: Migration Plan →](./06-migration-plan.md)
