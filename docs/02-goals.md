[← README](../README.md) | [← Prev: Current State](./01-current-state.md) | **Goals & Non-Goals** | [Next: Target Architecture →](./03-architecture.md)

---

# 2. Goals & Non-Goals

## 2.1 Goals

- Move test cases out of MongoDB into purpose-built object storage.
- Replace manual pre-round scaling with automated scaling driven by queue depth and contest schedule.
- Establish Multi-AZ resilience for every stateful component.
- Replace today's hand-rolled session auth with a managed identity provider that handles sign-up, sign-in, password reset, email verification, and MFA.
- Define a concrete monitoring and alerting posture — named alarms, paging topics, and a submit-and-poll canary that detects platform outages from a user's perspective.
- Centralise every log type (app, access, audit, network) into a single S3 logs bucket with retention and lifecycle policies.
- Add distributed tracing across the full submission path.
- Build a foundation for post-round ML analytics (cheating detection).
- Keep the `judge0` and `judge1` codebases largely unchanged — this is a platform migration, not a rewrite.

## 2.2 Non-Goals

- Rewriting `judge0` or replacing it with a custom executor.
- Real-time cheating detection during contests (post-round is sufficient and far cheaper).
- Multi-region active-active. Single region, Multi-AZ is the right target for our user base and budget.
- Migrating off BullMQ. BullMQ on ElastiCache Redis is a clean port.

---

[← README](../README.md) | [← Prev: Current State](./01-current-state.md) | **Goals & Non-Goals** | [Next: Target Architecture →](./03-architecture.md)
