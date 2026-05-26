[← README](../README.md) | [← Prev: Cheating Detection](./03-cheating-detection.md) | **Design Decisions** | [Next: Well-Architected →](./05-well-architected.md)

---

# 4. Key Design Decisions

These are the architectural decisions where a defensible choice matters more than the choice itself. Each is documented with options, choice, and rationale — the form an SAA exam item would test.

**4.1 Fargate vs ECS-on-EC2 for `judge0` workers.**
Options: Fargate, ECS-on-EC2, EKS, raw EC2 ASG.
Choice: **ECS-on-EC2.**
Rationale: `judge0` requires the `isolate` sandbox, which needs cgroups and privileged container capabilities. Fargate does not allow privileged mode, ruling it out. EKS would work but adds an operational layer not needed at this scale. Raw EC2 ASG would work but ECS gives declarative task definitions and rolling deploys for free. The orchestrator service has no such constraint and runs on Fargate.

**4.2 Amazon DocumentDB vs MongoDB Atlas on AWS.**
Options: DocumentDB, MongoDB Atlas (AWS-hosted), self-hosted MongoDB on EC2.
Choice: **DocumentDB**, with Atlas as a defined fallback.
Rationale: DocumentDB is MongoDB-compatible up to a specific API version and integrates natively with the rest of the AWS account (IAM, VPC, KMS, CloudWatch). Atlas is a more capable database with full MongoDB feature parity, but it is a separate vendor relationship, separate IAM, separate billing. **Decision gate**: if the application depends on Mongo features past DocumentDB's compatibility version (transactions across collections, change streams with complex filters, advanced aggregation operators), switch to Atlas. Self-hosting is rejected — the explicit theme of this architecture is exiting the "manage our own database" business.

**4.3 Spot vs On-Demand for `judge0` workers.**
Options: 100% On-Demand, mixed (On-Demand baseline + Spot for surge), 100% Spot.
Choice: **Mixed.** On-Demand for the steady baseline (1–2 instances), Spot for surge during contests.
Rationale: A killed `judge0` worker has a self-healing failure mode — the in-flight batch is simply re-queued by the orchestrator's timeout-and-retry logic — so Spot's interruption risk is tolerable. Cost savings are typically 50–70%. Keeping a small On-Demand baseline prevents Spot capacity unavailability from breaking idle-period traffic.

**4.4 Polling vs webhooks for `judge0` completion.**
Options: Poll `judge0` for batch completion, register `judge0` callbacks to an HTTPS endpoint.
Choice: **Poll in v1; webhooks in v2.**
Rationale: Polling is well-understood and decoupled from the orchestrator's reachability — a webhook receiver introduces a new public-or-VPC-internal endpoint and an extra failure mode. Once the platform is stable, replacing the poll loop with callbacks to an API Gateway endpoint would reduce latency and load on the queue — flagged in [Future Work](./07-future-work.md).

**4.5 Bedrock vs SageMaker for LLM-generated code detection.**
Options: Amazon Bedrock (fully managed FM inference), SageMaker real-time endpoint, SageMaker batch transform.
Choice: **Bedrock for v1, batch transform for scale.**
Rationale: Bedrock removes model hosting from the operational burden entirely and allows iteration on the prompt and grader without retraining. Per-inference cost is higher than a self-hosted classifier, but at the post-round, batch-able volume assumed here, this is acceptable. The path to SageMaker batch transform (using a fine-tuned model trained on moderator-labeled examples) is clean and warranted only if Bedrock costs cross a predefined threshold.

**4.6 Real-time vs post-round cheating detection.**
Options: Block at submission time, flag at submission time, flag post-round.
Choice: **Flag post-round.**
Rationale: Real-time blocking has unacceptable false-positive risk (an honest submission that resembles a known cheating pattern would be denied AC). Real-time flagging adds latency to the verdict path. Post-round runs on the full submission set in batch, supports more expensive signals (pairwise N² plagiarism), and gives moderators a curated queue rather than an alert stream.

**4.7 Identity provider — Cognito vs Auth0 vs self-managed.**
Options: Amazon Cognito User Pool, Auth0 (or another SaaS IdP), self-managed JWT inside the orchestrator.
Choice: **Cognito User Pool.**
Rationale: Cognito gives sign-up, sign-in, hosted UI, MFA, password reset, and JWKS-validated JWTs without any code to maintain, and integrates natively with ALB (auth action), API Gateway (Cognito authorizer), and SES (verification emails). The free tier covers the first 50K monthly active users, comfortably more than the assumed scale. Auth0 is more feature-rich (enterprise SSO, fine-grained RBAC UI) but introduces a separate vendor relationship and billing line — overkill for a contest platform. Self-managed JWT is rejected: rolling password reset, MFA, and rate-limited login flows from scratch is exactly the kind of work AWS has already solved.

**4.8 Next.js hosting — AWS-native serverless primitives (OpenNext) vs AWS Amplify Hosting vs Fargate SSR.**
Options:
- **AWS-native serverless primitives** in the OpenNext shape: CloudFront + S3 + Lambda (Server Function) + Lambda (Image Optimization) + DynamoDB (ISR tag cache) + SQS (revalidation queue).
- **AWS Amplify Hosting** — managed Next.js hosting that wraps the above into one service.
- **Next.js on ECS Fargate** — run the Next.js Node server as a long-lived container behind an ALB.

Choice: **AWS-native serverless primitives (OpenNext pattern).**
Rationale: The web app is a full Next.js application with heavy SSR, RSC, API routes, and Server Actions, so a static export is off the table immediately (it would lose most of the app's behaviour). Between the three real options:

- **Fargate SSR** is rejected because Next.js workloads are extremely bursty (a contest spawns thousands of requests in seconds, then idles between rounds). Paying for warm containers between rounds wastes money, and scaling containers is slower than scaling Lambda concurrency. The exception — cold-start sensitivity for the first few requests after idle — is addressed with **provisioned concurrency** on a scheduled action mirroring the `judge0` pre-warm.
- **Amplify Hosting** is a strong simplification — one service, one deploy command, native Next.js feature support — but for an SAA-level architecture the primitives matter: showing how CloudFront behaviours, Lambda Function URLs, DynamoDB tag caching, and SQS-driven background revalidation compose to *be* what Amplify is hiding is more educational and more controllable. Amplify is the fallback if operational burden of managing the primitives becomes real.
- **AWS-native primitives** give: per-component IAM scoping, per-Lambda CloudWatch / X-Ray observability, explicit control of CloudFront cache behaviours, and direct visibility into the cache (DynamoDB) and revalidation queue (SQS). This is also the design Next.js itself targets — the OpenNext community maintains the adapter that produces exactly this topology from a stock `next build`.

A side benefit: because the Server Function is VPC-attached, it can call the orchestrator over the **internal** ALB. CloudFront becomes the only public AWS endpoint, which is a meaningful security improvement.

---

[← README](../README.md) | [← Prev: Cheating Detection](./03-cheating-detection.md) | **Design Decisions** | [Next: Well-Architected →](./05-well-architected.md)
