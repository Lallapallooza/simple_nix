# System Architecture

A decision framework for system-level architecture choices -- the decisions that are expensive to reverse and shape everything that follows. Each topic is how a staff architect thinks about the trade-off, not the textbook definition.

---

## The Monolith Question

### 1. Monolith vs Microservices -- The Decision Framework

Microservices solve: team autonomy (independent deploy), deployment independence, isolated scaling (search needs 10x compute but admin panel doesn't). Microservices create: network failure modes, serialization overhead, distributed tracing requirements, operational complexity (N deployment pipelines, N monitoring dashboards, N on-call rotations).

**The decision framework:** Do you have (a) multiple teams needing independent release cycles, (b) components with genuinely different scaling requirements, AND (c) a platform team for the operational overhead? No to any -> modular monolith. Amazon Prime Video's VQA team cut infrastructure costs 90% by moving from microservices to a monolith -- S3 calls for intermediate storage replaced by in-memory data transfer.

**The smell:** Services deploy together >70% of the time. You have a distributed monolith.

### 2. When to Split a Monolith -- The 5 Operational Signals

"Too big" is not a signal. A 500K-line monolith deploying smoothly is healthier than 50 microservices requiring coordinated releases. The actual signals:

**Deployment contention:** Two teams repeatedly block each other's deploys -- not "could block," but actually do. **Divergent scaling:** Paying 10x compute for everything because one component needs it. **Blast radius:** A reporting bug takes down the payment path -- shared state/threads/memory. **Compliance isolation:** PCI/HIPAA forces the entire monolith through audit cycles. **Independent release cadence:** Team A ships daily, Team B monthly, and B's QA blocks A.

**What is NOT a signal:** Slow builds (fix the build). Hard to understand (fix code quality). "Too many lines" (not an architectural metric). Splitting a confusing monolith gives you confusing microservices plus network failures.

### 3. Deployment IS Architecture

Your deployment topology is your actual architecture. Your code structure is your aspirational architecture. When they diverge, deployment wins.

90% of microservices teams batch-deploy like monoliths because integration tests require all services, schema changes coordinate across boundaries, and the release train waits for the slowest service. If your CI/CD builds and deploys everything together, you have a monolith with network calls.

**The judgment:** Track your co-deployment percentage. If it's above 70%, structure as a modular monolith. Get modularity benefits without distribution costs.

---

## Evolution & Rewrites

### 4. The Rewrite Decision -- Strangler Fig, Second-System Effect, and Sacrificial Architecture

The total rewrite is almost always wrong. Netscape's ground-up rewrite took three years. During that time, Microsoft shipped features and captured the market. Netscape was acquired by AOL mid-rewrite (1998), and when Netscape 6 finally shipped in 2000, it flopped. The problem is structural: a total rewrite must replicate every feature and edge case while the existing system keeps evolving.

**The second-system effect (Brooks):** After a successful first system, every abandoned idea is deferred to the successor. The second system collapses under accumulated ambition. OS/360, Multics, Netscape 6. The modern version: v2 design docs that spend more pages on what's wrong with v1 than on what v2 needs to do. Design from current requirements, not from resentment of the first system.

**Jeff Dean's counter-prescription:** "Design for ~10X growth, but plan to rewrite before ~100X." This schedules the rewrite as a lifecycle event, not a crisis response. The rewrite happens while the team can still complete it.

**The strangler fig works:** Wrap old functionality with a facade, incrementally implement new services behind it. Abort at any point with a working system. Fails when: the facade becomes feature-laden, teams stop mid-migration and maintain two systems, behavior parity isn't validated.

**Sacrificial architecture (Fowler):** "Often the best code you can write now is code you'll discard in a couple of years." eBay: Perl (1995) -> C++ (1997) -> Java (2002). Each was correct for its era. The first version's job is learning what users want. The second version's job is scaling. Over-engineering the first for hypothetical 100x scale -- at the cost of velocity for product-market fit -- is the more dangerous mistake.

**The smell:** "We'll do it right this time" -- that's the second-system effect. Or: your team spends more time on "doing it right" than discovering what users need.

---

## Data & Integration

### 5. Data Model as Destiny

Your data model is the most consequential architecture decision, usually made in week 2 by the most junior person on the team. Every other decision is constrained by the schema.

**Cases where data model created irreversible advantage:** Slack's persistent searchable channels -- competitors can't replicate without rebuilding customer workflows. Figma's shared web canvas -- Adobe's desktop-first architecture can't address collaborative editing without deprecation. Toast's menu items with embedded kitchen logic -- generic POS systems can't naturally extend to kitchen management.

**The specific trap:** Choosing single-table inheritance vs table-per-type in week 2 determines whether adding entity types is cheap or requires schema migrations. This casual decision constrains the system for years.

**The smell:** "Our schema can't support that" is your first reaction to a new feature. Your data model is constraining product evolution.

### 6. Schema Migrations -- The Hardest Problem Nobody Talks About

Every schema migration is a deployment. The "just run ALTER TABLE" mentality kills production.

**Additive migrations are safe:** New columns with defaults, new tables. Online with minimal locking.

**Destructive migrations are deployment events:** Column renames, type changes, table drops require multi-phase approaches: (1) add new column, (2) dual-write, (3) backfill, (4) switch reads, (5) drop old column. A "simple rename" becomes 5 deployments over 2 weeks. Most teams discover this during the migration.

**The smell:** Your migration script runs longer than 30 seconds. Check the row count and test on production-sized data before deploying.

### 7. Events vs Calls vs Shared Database

Event-driven architecture enthusiasm glosses over three production problems:

**Debuggability collapses.** You must watch logs and traces, not read code. Correlation IDs and distributed tracing are prerequisites, not accessories. Without them: grep through logs from 12 services hoping timestamps align.

**"All or nothing" flows are nearly impossible.** When a flow needs transactional behavior across services, synchronous calls with sagas are easier than event choreography. Richards/Ford (Architecture: The Hard Parts): "As workflow complexity increases, the need for an orchestrator rises."

**The practical rule:** Events for genuinely async operations (notifications, audit logs, eventual consistency). Synchronous calls when the caller needs the result. Shared database when the data model is shared and teams can coordinate schema changes.

### 8. Shared Database as Correct Choice

For teams under 20 engineers with services sharing a data model, a shared database with schema ownership conventions is dramatically simpler than synchronizing via events, CDC, or API calls.

**When shared is correct:** Services' ER diagrams share >30% of entities. Team is small enough for schema coordination. You need strong consistency across shared data.

**When to split:** Genuinely independent data models. Different teams with different release cycles. Independent storage scaling. Compliance requires physical isolation.

**The smell:** Architecture diagram has arrows labeled "sync" or "replicate" between databases. You're paying the distributed data tax without the distributed team benefit.

### 9. Caching as Architecture -- Wrong First, Right Second

**Wrong first instinct:** Slow endpoint gets Redis cache. 2s -> 50ms. Except: cache masks a missing index, introduces stale data, creates cascading failure when Redis dies.

**Right second instinct:** Optimize query first (add index, fix N+1). 2s -> 200ms. Now cache on optimized data: 200ms -> 20ms. Cache misses are survivable. System degrades gracefully.

**The thundering herd:** 10,000 req/min cached with 5-min TTL. Key expires -> all 10,000 hit the database. Facebook's fix: lease-based locking (first requester gets lease, others wait and retry cache). Probabilistic early expiration (jitter) spreads misses.

**Three-condition test:** (1) Read-heavy, (2) changes infrequent, (3) stale data acceptable. If any is false, caching is a band-aid.

**The unmeasured cost:** Caching makes bugs irreproducible locally. "Is it a bug or stale cache?" becomes the default investigation question.

---

## Organizational Architecture

### 10. Conway's Law as Physics

If your frontend and backend teams are separate organizations, you will get a frontend/backend architecture regardless of design documents. Conway's Law is not advice -- it's physics.

**The inverse Conway maneuver:** Restructure teams to produce the architecture you want. Team Topologies (Skelton/Pais): stream-aligned, enabling, complicated-subsystem, and platform teams -- each designed to produce specific coupling patterns. The limit: reorganizing teams without changing architecture produces nothing. The implication: assigning module ownership is an architectural act. Creating a platform team is an architectural act. Splitting a team is splitting a service.

### 11. Bezos API Mandate -- Designing for External From Day One

Five rules from the 2002 Bezos memo (surfaced by Steve Yegge's 2011 Google rant): all teams expose data through service interfaces, no other IPC, technology choice doesn't matter, all interfaces externalizable from day one -- or you're fired.

**The consequence:** Amazon built AWS as a side effect. Designing for external use creates interface discipline internal-only APIs never develop.

**The selective application:** At smaller scale, treating every internal API as external-grade is too expensive. Treat APIs crossing team boundaries with external discipline. Treat within-team APIs with internal flexibility. If exposure to customers is plausible within 2 years, design for external from day one -- retrofitting is a rewrite.

---

## Meta-Architecture

### 12. Build vs Buy -- What NOT to Build

The senior architect's highest-value contribution is often "we don't need this" or "use off-the-shelf." The 80th-percentile off-the-shelf solution with zero maintenance beats the 95th-percentile custom solution with permanent maintenance -- unless the feature is your core differentiator.

**The political dimension:** The "right" architecture sometimes loses to org politics. Proposing an architecture the organization cannot execute is proposing a bad architecture. Execution feasibility is an architectural requirement.

**The smell:** Custom deployment system, custom monitoring, custom message broker -- and features ship quarterly. Infrastructure that doesn't differentiate your product.

### 13. Emergent Architecture -- Intentional at Large, Emergent at Small

Intentional architecture at the large scale (service boundaries, data flow patterns, technology choices). Emergent design at the small scale (implementation details, internal data structures). Decide big shapes deliberately. Let small shapes discover themselves through iteration.

**Fitness functions as guardrails:** Architectural constraints encoded as CI/CD tests -- latency SLOs, coupling metrics, dependency direction checks -- catch drift in measurable properties. But the fatal mistakes (wrong service boundaries, wrong data ownership) are never the ones you can test for. Fitness functions protect the measurable; judgment protects the rest.

**The signal:** Nobody can draw your architecture on a whiteboard. Architecture that only exists in code and nobody can articulate is accidental architecture.

### 14. Reversibility Heuristic -- Irreversible Decisions Deserve Weeks

The most important question: not "what is the best option?" but "how reversible is this decision?"

**Reversible (hours):** Library choices, internal APIs, service names, response formats. Make quickly, change when wrong.

**Irreversible (weeks):** Database engine, programming language, data model, public API contracts, on-disk formats, wire protocols. Design docs, team review, careful analysis. The cost of a wrong irreversible decision exceeds weeks of deliberation.

**The trap:** Most teams spend equal time on both. 3-meeting debate over HTTP client library AND 2-hour database schema design. Inverted effort.

### 15. LLVM's Lesson -- Breaking Compatibility for Internal Progress

Chris Lattner on LLVM: the three-phase design (front end -> IR -> back end) enables N+M components instead of NxM. But "LLVM's modularity was a self-defense mechanism: it was obvious that we wouldn't get everything right on the first try."

**The compatibility strategy:** LLVM breaks internal APIs freely. The boundary is the IR specification -- everything else can change. This is the opposite of Torvalds's userspace rule -- but both agree on the principle: stability at the boundary, freedom inside. Your system has a boundary too -- identify it explicitly. Everything outside gets permanent guarantees. Everything inside gets freedom to evolve.

**The signal:** You're hesitant to refactor an internal API because "too many things depend on it." Either promote it to a stable boundary or break it now. The middle ground -- treating internal as external without the versioning discipline -- is the worst option.
