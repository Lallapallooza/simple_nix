# Interface Design & API Architecture

A decision framework for API design, module interfaces, and architectural contracts. Each topic is how a staff architect thinks about the trade-off, written for someone who knows the principles but hasn't yet internalized when to break them.

All architecture advice is context-dependent: what's true at 3 engineers is false at 300, what's true for CRUD is wrong for real-time, what's true for startups is wrong for banks. Calibrate every topic against your scale, domain, and team before applying.

---

## API Surface & Contracts

### 1. Deep vs Shallow Modules -- When Shallow Is Correct

Ousterhout's ratio -- (complexity hidden) / (interface complexity) -- is a powerful heuristic. But it has a blind spot: testability. Deep modules are hard to unit-test because they do too much behind a small interface. Shallow methods that take explicit dependencies as parameters can be composed and tested independently. The senior judgment: deep modules optimize for the reader of the interface, shallow modules optimize for the writer of tests. Beware that shallow modules increase layer count -- apply this within a bounded service, not across service boundaries.

**When deep is correct:** Public APIs consumed by external teams. Infrastructure libraries (HTTP clients, database drivers, serializers). Anywhere the caller should not need to understand the implementation.

**When shallow is correct:** Internal modules where the team owns both sides. Code under active development where the interface is still being discovered. Components that need fine-grained test control over behavior.

**The smell:** You can't test a module without mocking three layers beneath it. That module is too deep for its current lifecycle stage.

**The signal:** Your public API has 30 methods and callers routinely use only 3. That module is too shallow -- it's exposing internals as interface.

### 2. API Surface Area -- Fewer Powerful vs Many Fine-Grained

Rob Pike's Go proverb: "The bigger the interface, the weaker the abstraction." The test: if 80% of callers use the same 2 methods, the other 28 methods are interface pollution.

**The counter-case:** A graphics API needs `drawLine`, `drawRect`, `drawCircle` -- collapsing these into `draw(shape)` pushes a type switch onto the implementation and loses compile-time exhaustiveness. Fine-grained is right when each method represents a genuinely different operation, not when it represents a different configuration of the same operation.

**The signal:** Your interface has methods that differ only in one parameter's type or value. Those should be one generic method, not N specialized ones.

### 3. Hyrum's Law -- Defense by Randomization, Not Documentation

"With a sufficient number of users of an API, it does not matter what you promise in the contract: all observable behaviors of your system will be depended on by somebody." -- Hyrum Wright, Google.

Google's internal JDK fork deliberately randomizes HashMap iteration order per-process invocation, because despite documentation saying order was "unspecified," thousands of internal call sites silently depended on stable ordering. Go randomizes map iteration order for the same reason. Python added `PYTHONHASHSEED` randomization.

**The non-obvious defense:** Documenting "this behavior is not guaranteed" buys almost nothing at scale. The only reliable defense is to actively randomize or rotate behavior to prevent stable implicit contracts from forming. The cost: harder debugging and potential performance overhead from randomization -- but cheaper than an implicit contract you discover only when you need to change the behavior.

**The smell:** A "non-breaking" internal change breaks someone. The fix is not "warn callers harder" -- it's to make the undocumented behavior unstable enough that nobody can depend on it.

### 4. API Stability -- The Compound Cost and When to Break It

Every optional parameter you add is technical debt that compounds. The first is fine. The tenth means callers must understand all ten to know which ones interact. Stripe handles this with rolling date-based API versions -- each backwards-incompatible change is a separate version-change module applied backwards through time to reach the caller's pinned version.

**The Torvalds principle:** Linus Torvalds, December 2012, after a media subsystem commit changed ioctl error codes from `-EINVAL` to `-ENOENT`, breaking PulseAudio: "WE DO NOT BREAK USERSPACE." The kernel never blames the application. Internal kernel APIs change freely -- thousands of breaking changes per release. External userspace ABIs never break. This asymmetry -- internal flexibility, external immutability -- is how Linux maintains backward compatibility for decades while rewriting internals.

**The three-tier rule:** Public APIs (external consumers you don't control) get permanent backwards compatibility. Internal APIs (between teams) get deprecation timelines. Internal implementation gets changed whenever needed. If you can't distinguish these three in your codebase, your API boundary is leaking.

**When to explicitly NOT guarantee stability:** Internal APIs between teams in the same organization. Permanent internal stability means permanent internal constraint.

**The smell:** A function with 8 parameters, 5 optional for backwards compatibility. Nobody knows which combinations are used. Or: a compatibility shim for behavior nobody remembers the reason for -- check if external consumers depend on it before keeping it forever.

### 5. Error Design as API Surface

Error types are part of your API contract -- they shape how callers build recovery logic. Stripe includes a `doc_url` field in every error response, treating errors as first-class API surface. gRPC's 17 status codes force callers to map application semantics onto infrastructure codes -- the error taxonomy IS the coupling point.

**The judgment:** If your HTTP handler returns `diesel::Error`, you've coupled your API layer to your database. Each architectural layer should have its own error type, with explicit conversion at boundaries. The cost: boilerplate of per-layer error types. The benefit: swapping a database doesn't rewrite your HTTP layer.

**The rule for error granularity:** Library errors should be machine-readable (structured enums callers match on). Application errors should be human-readable (context chains operators read in logs). Don't make one type serve both.

**The smell:** A `use sqlx::Error` in your HTTP handler module. Or `anyhow::Error` in a library's public API, forcing callers to downcast.

### 6. Configuration as Design Smell

Every configuration option is a decision you punted to the operator. Configuration proliferation signals a system that lacks opinions.

**The judgment:** Configuration that controls behavior (retry counts, timeout values) should have good defaults for 90% of deployments. The test: if changing this config value could break the system, it shouldn't be config -- it should be a code change that goes through review. The counter-case: multi-tenant systems and regulated environments genuinely need operator-controlled behavior without code deploys.

**The smell:** A YAML file with 200 keys where operators must understand 50 to get the system running. That's not configuration -- that's an unfinished design.

---

## Type System Judgment

### 7. Making Illegal States Unrepresentable -- When the Ceremony Costs More

The principle is powerful: if a state is invalid, the type system should make it impossible to construct. A `Contact` that must have email or phone should be `EmailOnly | PhoneOnly | EmailAndPhone`, not two optional fields where both-None is representable.

**When it's worth it:** Public APIs where invalid states cause silent data corruption. State machines with well-defined transitions. Domain types where swapping arguments is a silent bug (AccountId vs OrderId). Any ID, measurement with units, or domain concept that "happens to be" a number or string -- make it a newtype when it crosses a module boundary. The trap: implementing `From<u32> for UserId` AND `From<u32> for OrderId` defeats the newtype's purpose -- use named constructors.

**When the ceremony costs more:** Internal code with 2-3 callers who all understand the constraints. Prototyping where encoding the wrong invariants is worse than encoding none. Data types with 15 states where each variant creates a combinatorial explosion of match arms.

**The smell:** You're adding `#[allow(dead_code)]` to type variants for completeness. Or your match has 12 arms where 10 do the same thing. Or `if email.is_none() && phone.is_none()` scattered across 6 methods -- that check should be a type.

### 8. Parse-Don't-Validate -- The Boundary Discipline

Validate raw input once at the system boundary. Return a typed result. Never re-validate deeper in the call stack. A `ValidatedEmail` constructed at the boundary carries proof of validity through the entire call chain.

**When to skip it:** Internal utilities where the boundary is two lines above. One-shot scripts. Anywhere the wrapper type costs more than the bug it prevents -- which, for internal code with one caller, is often.

**The smell:** The same validation check appears in 3+ files. Each is a potential inconsistency.

### 9. Type-Level Enforcement Has a Readability Ceiling

Encoding invariants in the type system is powerful -- until the function signature becomes `fn process<S: State<Prev = Validated, Next = Committed>, T: Transport<Session<S>>>`. At some point, the type-level proof is harder to understand than a runtime check.

**The sweet spot:** Types for invariants that would be dangerous to violate (SQL injection, authentication status, unit conversions). Runtime checks for invariants that would be inconvenient to encode (business rules, configuration validation). If a new team member can't understand the type signature in 30 seconds, you've gone too far. What you give up by choosing runtime checks: late failure discovery, production bugs that types would have caught at compile time.

**The smell:** Your type-level state machine has 8 states and nobody can add a new state without understanding the entire type lattice. A runtime enum with `debug_assert!` would catch the same bugs with 90% less complexity.

---

## Structural Principles

### 10. Law of Demeter -- When Chains Are Fine

The mechanical rule: don't navigate through objects you received to reach objects they hold. `order.getCustomer().getAddress().getCity()` couples you to Order, Customer, AND Address.

**When the rule is wrong:** Ted Kaminski's counterargument: adding wrapper methods doesn't fix the design -- it scatters cohesive logic across classes and adds API surface. David Copeland: for data classes and standard library types, Demeter "does more harm than good." The right fix is questioning whether the dependency chain should exist, not wrapping it.

**The judgment:** Demeter is valuable at system boundaries where dependencies become permanent contracts. Inside a domain model, it harms code quality by misdirecting refactoring effort. `user.address.city` is fine. `orderService.getRepo().getConnection().execute()` is a real violation. The risk of ignoring Demeter internally: if the domain model restructures, all chain callers break -- but within a team's codebase, that's a manageable cost.

**The signal:** You're adding `get_delivery_city()` to Order just to hide `customer.address.city`. Is this method serving any caller other than the one that prompted its creation?

### 11. Interfaces Are Forever, Implementations Are Temporary

An ugly implementation behind a clean interface can be replaced without coordinating with consumers. A beautiful implementation behind a leaky interface traps you forever.

**The 80/20 allocation:** Spend 80% of design time on the contract, 20% on the implementation. Most teams invert this. Identify which interfaces are permanent (external consumers, on-disk formats, wire protocols) and which are temporary (internal module boundaries). Invest design effort proportional to permanence.

**The smell:** You're reluctant to change an internal module boundary because "too many things depend on it." That boundary has become a permanent interface by accident. Either commit to it (stabilize, document, version) or break it now before more consumers arrive.

### 12. The Database IS the Real API

For systems with multiple consumers -- web app, mobile app, analytics, internal tools -- the database schema is the de facto API. Changing a column name is a breaking change because someone has written a report query against it. The cost of treating schema as public API: versioning overhead, slower schema evolution. The cost of not doing so: breaking N downstream consumers you didn't know existed.

**The signal:** Your database has read replicas used by other teams. Your schema has views consumed by analytics. An ETL pipeline depends on column names. Your schema is a public API.

**The smell:** A column rename that breaks three dashboards nobody on your team knew about.

### 13. Lampson's Brute Force Hint

Butler Lampson, "Hints for Computer System Design" (1983): "When in doubt, use brute force." A straightforward, easily analyzed solution that requires many computing cycles is better than a complex, poorly characterized one.

**The judgment:** A linear scan of 10,000 items in memory takes microseconds. Building a hash index for "O(1) lookup" adds complexity, memory overhead, and failure modes -- and is slower for small N due to constant factors. Jeff Dean's latency numbers: main memory reference is ~100ns. A brute-force scan of 10KB in L1 cache beats a pointer-chasing "optimized" algorithm that causes cache misses.

**The smell:** An elaborate caching/indexing layer for a dataset that fits in a single L2 cache line. Profile first.

### 14. Sealing Extensibility Points

A public trait or interface that anyone can implement is an extensibility point. Sometimes that's a liability -- every new implementation is something you must consider when changing the trait.

**When to seal:** Invariants that can't be expressed in types. Adding a new method shouldn't be a breaking change. The interface is consumed, not implemented, by external code.

**When to leave open:** Plugin systems, codec registries, middleware chains.

**The judgment:** Once you open an extension point, closing it is a breaking change. Once you seal it, opening it is easy. Default to sealed; open when there's demand. The cost of over-sealing: frustrated consumers who fork or abandon your library.

**The smell:** 15 external implementations and you can't add a method without breaking all of them.
