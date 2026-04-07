# Failure, Scale & Distributed Systems

A decision framework for designing systems that fail well. Each topic is how a staff engineer thinks about failure, latency, and distributed systems trade-offs -- not the theoretical treatment, but what actually bites in production.

---

## Failure Design

### 1. Failure Mode Design -- Hard vs Soft Dependencies

Netflix's operational principle: classify every dependency as hard or soft before production. Hard = feature cannot function at all if dependency fails. Soft = feature degrades but works.

**Hard dependencies must be minimized.** If checkout hard-depends on recommendations, a recommendation outage takes down checkout.

**Soft dependencies need explicit fallback paths.** Netflix: personalization down -> precomputed popular content. Real-time ranking down -> cached results. Feature flags and kill switches at every service boundary, not just the perimeter.

**The judgment:** Most dependencies are soft but treated as hard by default because nobody designed the fallback. The question isn't "what if this fails?" -- it's "what does the user see when this fails, and have we designed that experience?" Every system boundary needs both fail-fast (reject doomed requests immediately) and graceful degradation (serve partial results for viable requests).

**The smell:** A service timeout cascades into a 500 error. The failing dependency was for analytics, not the core flow. Or: your system either works 100% or shows a 500 page -- no middle ground.

### 2. Error Budgets -- 100% Reliability Is Explicitly Wrong

Google SRE book: "100% is probably never the right reliability target." Each incremental nine costs exponentially more, and users on 99% reliable phones can't perceive the difference between 99.99% and 99.999%.

**The architectural impact:** Error budgets resolve the product-vs-SRE deadlock. Budget unspent -> take risks, deploy often. Budget nearly exhausted -> developers self-police. A 99.9% SLO gives 43 minutes of downtime per month -- enough for daily deploys without heroics.

**The smell:** An unwritten goal of "zero incidents." That's a culture of fear, not an SLO. Define the acceptable failure rate and spend the budget.

### 3. Dead Code as Time Bomb -- Knight Capital's $440M Lesson

August 1, 2012: Knight Capital deployed new code to 7 of 8 servers. The 8th still ran "Power Peg" -- a test algorithm decommissioned in 2003 that intentionally bought high and sold low. A config flag reused for a new feature activated Power Peg unthrottled. $440 million lost in 45 minutes -- exceeding the firm's net worth.

**The failure chain:** Dead code reachable via any config path is live code. A 2005 refactoring disconnected Power Peg from its throttle but never removed the code. Manual deployment without automated verification. 97 internal emails saying "Power Peg disabled" treated as noise. No kill switch, no circuit breaker. And when engineers "fixed" it by reverting the 7 good servers to old code, they activated Power Peg on ALL 8 servers, multiplying the loss.

**The rule:** The only safe dead code is deleted code. Config flags reused for unrelated features are time bombs.

**The smell:** A code path gated by a config flag "nobody uses anymore." Delete it or test it.

### 4. Silent Failure Stacking -- GitLab's Five Backup Systems

January 31, 2017: GitLab lost 300GB of production data. An engineer deleted the primary database directory. Five backup systems had silently failed.

**The stack:** pg_dump: wrong binary version, silent error. Email notifications: rejected (missing DMARC signatures). Azure snapshots: not enabled for DB servers. LVM snapshots: 24h old, 18h to copy (~60 Mbps throttled storage). WAL archiving: not configured.

**The lesson:** Each system failed independently and silently. Nobody monitored the monitors. The failures weren't independent -- they shared a common cause: nobody owned backup verification as a primary responsibility.

**The rule:** Test backups by actually restoring from them. If DR hasn't been tested end-to-end in 90 days, you have a DR wish, not a DR plan.

### 5. Speed as Vulnerability -- Cloudflare's Regex Outage

July 2, 2019: Cloudflare's WAF update with catastrophic-backtracking regex (`.*(?:.*=.*)`) took down ~80% of traffic for 27 minutes.

**The strength became the weakness:** Quicksilver pushes changes globally in seconds. WAF rules deliberately skipped staged rollout (DOG -> PIG -> Canaries -> Global) for emergency threat response. The bypass created the catastrophic path.

**The recursive failure:** Engineers couldn't access their own control panel -- it depended on the same infrastructure that was down.

**The lesson:** Fast deployment pipelines require staged rollout discipline. The exception carved out for "emergency response" is the exception that will cause the emergency.

**The smell:** Your deployment has a "fast path" that skips canary testing. That path will be used for the change that needed canary testing most.

---

## Latency & Performance

### 6. Latency Budgets -- Jeff Dean's Numbers and the 100,000x Gap

| Operation | Latency |
|---|---|
| L1 cache reference | ~0.5 ns |
| Main memory reference | ~100 ns |
| NVMe SSD read | ~10-100 us |
| Network round trip (datacenter) | ~500 us |
| Disk seek (spinning) | ~10 ms |
| CA -> Netherlands -> CA | ~150 ms |

**The architectural implication:** In-process calls are ~100,000x faster than service-to-service calls. Any architecture decision replacing in-process with network calls must justify that penalty. For tightly coupled pipelines with high-frequency internal calls, in-process is correct.

**The compound effect:** A chain of 5 services at 50ms p50 each = 250ms p50. But the p99 approaches the sum of p99s, not p50s -- if each has 200ms p99, the chain's p99 is ~1000ms. This is invisible in per-service monitoring.

### 7. Tail at Scale -- The Math Nobody Checks

Dean and Barroso (2013): with 1% of requests at 1s P99, and fan-out of 100 servers, 63% of user requests hit that tail.

**Hedged requests:** Send the same request to two replicas after the 95th-percentile expected latency. Cancel the slower one. Google BigTable benchmark: hedging after 10ms reduced P99.9 from 1,800ms to 74ms -- adding only 2% more load. Sending duplicate requests makes the system faster overall.

**The judgment:** Per-service dashboards lie at scale. A service with 10ms p99 is fine -- until called by 50 services fanning out to 20 instances. Measure end-to-end at the edge, not per-hop.

**The smell:** Per-service dashboards are green but users say the app is slow. Add end-to-end latency measurement at the API gateway.

---

## Distributed Systems Reality

### 8. CAP in Practice -- Endpoint by Endpoint

You don't "pick two." You always have partitions. The choice: during a partition, serve stale data (AP) or refuse to serve (CP)? The answer is per-endpoint.

Payment API -> CP (reject, don't double-charge). Product catalog -> AP (stale price is acceptable). Real systems are a mix, not a single switch.

**The more important theorem:** PACELC. During normal operation (99.9% of the time), the real trade-off is Latency vs Consistency. Most teams spend engineering time on L/C, not P/A.

**The smell:** Someone describes your system as "CP" or "AP" as if it's a single switch.

### 9. Idempotency in Distributed Systems -- A System Property, Not an Endpoint Feature

"Exactly-once delivery" is actually at-least-once with idempotent processing. True exactly-once is impossible (Two Generals' Problem). If your system behaves differently when a message is delivered twice, you have a bug.

**What you build:** Every mutating operation gets an idempotency key. Consumers store processed keys. Conditional writes (`WHERE status = PENDING`) ensure first-processing-wins. Response storage is mandatory -- without it, retries get different responses.

**Stripe's atomic phases:** Decompose requests into groups of local mutations committed atomically, separated by external calls. Retry logic resumes from the right phase, not from scratch. The entire chain must be idempotent -- not just the first endpoint. Retrofitting idempotency is a rewrite.

**Jitter in retry logic:** Random backoff timing prevents thundering herds -- all failed clients retrying simultaneously after a fixed interval. This small detail is the difference between recovery and re-failure.

**The smell:** Retry logic in the API gateway and no idempotency keys downstream. Every retry is a potential duplicate.

### 10. Event Sourcing -- Great Theory, Terrible Default

**The promise:** Audit trail, temporal queries, event replay.

**The production reality** (Chris Kiehl): Scaffolding consumes sprints before feature work. Requirements shift and "immutable facts" lose accuracy. Event rewrites destroy the audit trail. Materialization lag kills read-after-write consistency (404s on freshly created data).

**When correct:** (1) Domain is inherently event-based (banking, logistics). (2) Temporal queries are primary, not afterthought. (3) Team has prior experience. (4) Can afford 3-6 month productivity hit.

**The 90/5 rule:** If "audit trail" is the justification, an append-only audit table provides 90% of the benefit at 5% of the complexity.

### 11. When Queues Are the Wrong Answer

**Wrong for:** (1) Synchronous needs -- caller needs the result now. (2) Low volume -- 50 req/day doesn't need Kafka; cron works. (3) Ordering matters more than throughput -- single-threaded DB reader is simpler. (4) Query/browse semantics -- that's a database, not a queue.

**The signal:** You're building a DLQ, then a UI to browse it, then retry logic, then DLQ depth monitoring. You've built a bad database out of queues. A database table with a status column would solve it with zero operational overhead.

---

## Production Lessons

### 12. Let It Crash -- Armstrong's Prerequisites

Joe Armstrong's philosophy is not "ignore errors." It's a specific architecture with specific prerequisites.

**The prerequisite nobody mentions:** Processes must share no memory. Erlang processes communicate only through message passing -- a crashing process cannot corrupt another's state. Without isolation, "let it crash" means "let it corrupt." Armstrong: "Process boundaries are like firewalls for failures, and they cost almost nothing."

**The architecture:** Supervision trees. Supervisors watch workers and restart them. Workers crash on unexpected states. The supervisor decides restart strategy. Error handling is structurally separated from the code that can fail.

**Four prerequisites:** (a) Process isolation, (b) supervisor restart policies, (c) low crash-and-restart cost, (d) reconstructable state. Without all four, crashing means data loss.

**The smell:** "We'll use the Erlang approach -- let it crash" in a system with shared mutable state and no supervision trees. That's not Erlang -- that's hoping for the best.

### 13. Chaos Engineering -- What Yuan et al. Actually Found

Yuan et al. ("Simple Testing Can Prevent Most Critical Failures," OSDI 2014) found that "92% of catastrophic system failures were the result of incorrect handling of non-fatal errors" -- studying Cassandra, HBase, HDFS, MapReduce, and Redis. The errors weren't primary failures -- the error handlers were wrong.

**What chaos experiments find:** Services storing state locally instead of remotely (invisible until instance terminates). Retry storms: 100 clients timeout simultaneously, all retry, overwhelming the recovering server. Circuit breakers configured but never tested. Fallback paths bit-rotted from disuse.

**The incident dimension nobody writes about:** "There is one administrator" -- from the distributed systems fallacies. During complex failures, the knowledge to fix it is distributed across teams and time zones. The person who knows how to fix it isn't available. Post-mortems regularly reveal this.

**The judgment:** Chaos in business hours, in production, with engineers present, shifts failure discovery to a controlled environment. Systems designed assuming chaos fail differently than systems designed to prevent failure.

**The signal:** Retry logic, circuit breakers, fallback paths -- never triggered in production. Run a chaos experiment before production does it for you.

### 14. Graceful Degradation vs Fail-Fast -- Different Levels, Same System

**Fail-fast at the component level:** Bad database connection -> fail immediately, not hang 30 seconds. Invalid auth -> reject at gateway, not propagate through 5 services. Fail-fast prevents resource exhaustion from doomed requests.

**Graceful degradation at the system level:** Recommendations down -> popular items. Real-time pricing down -> cached prices. Search slow -> curated categories. The system provides value even with features unavailable.

**The judgment:** Every system boundary needs both. Fail-fast on requests that cannot succeed. Degrade gracefully on requests that can partially succeed.

**The smell:** Your system either works 100% or shows a 500 page. No middle ground designed.
