# Senior Go Engineering Judgment

A decision framework for Go architecture, not a checklist. Each topic is how a staff engineer thinks about the trade-off, written for a mid-level who knows the language but hasn't yet internalized when simplicity is the feature, when to copy instead of abstract, or when a goroutine is the wrong tool.

This file covers senior engineering judgment for Go: WHEN and WHY behind design trade-offs.

---

## Go's Simplicity -- When It's the Feature

### 1. The Simplicity Transfer

Go is simple to specify. It is not simple to use. The language pushes complexity from the specification to the programmer -- you write the loop, you write the error check, you write the type conversion. Rob Pike's "Simplicity is Complicated" (dotGo 2015) makes this explicit: goroutines look like threads but aren't, maps look like simple data structures but have complex internal behavior. The simplicity is designed, not accidental.

**The judgment:** When someone says "Go is too simple for this problem," they usually mean "Go makes me do work that other languages hide." That's the point. The question is whether the hidden work in other languages would bite you later (concurrency bugs, implicit allocations, exception control flow) or whether Go is genuinely forcing unnecessary ceremony. For infrastructure, servers, and CLI tools -- Go's trade-off is usually right. For expression-heavy domains (compilers, data pipelines, ML) -- the ceremony cost can exceed the clarity benefit.

**The smell:** You're fighting Go's design instead of working with it. Three levels of nested generics, six-parameter functional options, adapter layers that exist only to satisfy an interface -- you're writing Java in Go syntax.

### 2. "A Little Copying Is Better Than a Little Dependency"

Rob Pike's proverb reacts against Google's heavy code-reuse culture and its compilation/maintenance costs. Russ Cox formalized the framework (research.swtch.com/deps): dependency risk = sum of (cost x probability) for all bad outcomes. Copying a small utility eliminates transitive dependency risk entirely.

**When it's wisdom:** Single-purpose utility functions (10-50 lines), stable algorithms that won't need security patches, code where the dependency would pull in a large transitive graph. Cox's own data: 30% of 750,000 NPM packages depend indirectly on `escape-string-regexp`. That's the risk you're avoiding.

**When it's an excuse:** Security-sensitive code (crypto, TLS parsing), complex algorithms with known CVE history, anything where "maintaining your copy" means silently missing upstream security fixes. If the thing you're copying has had CVEs, you need the upstream, not a snapshot.

**The signal:** You can articulate what risk the dependency introduces. If the answer is "it might change its API" -- that's manageable. If the answer is "it pulls in 40 transitive dependencies and any of them could be compromised" -- copy.

### 3. Generics -- When They Make Code Slower

Go 1.18 generics use GCShape stenciling, not full monomorphization. All pointer types share one GCShape -- `*time.Time`, `*uint64`, `*bytes.Buffer` compile to the same shape. This prevents inlining and devirtualization. PlanetScale's benchmarks (2022) measured this concretely: generic with pointer types was 7.18µs vs direct pointer at 5.06µs vs interface at 6.85µs. Generics were *slower than interfaces* for pointer types.

**When generics win:** Value types where the concrete type is known at compile time (full inlining possible). `[]byte | string` constraints. Data structures replacing `interface{}` -- type safety AND performance improvement. Functional algorithms over slices of value types.

**When generics lose:** Anything with pointer-typed type parameters on hot paths. Generic code using broad interface constraints (measured at 17.6µs vs exact interface at 9.68µs -- global hash table lookups on every method call). Generic methods don't exist and the Go team says they never will (FAQ: "We do not anticipate that Go will ever add generic methods").

**The smell:** You're making code generic that has exactly one concrete instantiation. You're building a generic repository pattern. You're using generics because they exist, not because you have multiple concrete types that need the same algorithm. DoltHub's analysis: generics in current form "feel like a compromise" -- simple and limited, easy to write "overwrought generic code whose added complexity hampers readability."

### 4. No Enums, No Sum Types -- The Exhaustiveness Gap

Go's `iota` pattern gives you named integer constants with no compiler enforcement. `Vehicle(42)` compiles without error. No exhaustive switch checking -- adding a new case to your pseudo-enum doesn't warn about unhandled arms. The Go Developer Survey 2024 H1 confirms: enums, option types, and sum types are the most commonly requested missing type system feature.

**When iota is enough:** Internal constants within a package where all switch sites are under your control. Status codes where the default case is genuinely correct ("unknown status -> log and continue"). Small, stable sets that rarely gain new values.

**When you miss sum types:** API boundaries where callers switch on your types and new values are breaking changes. Parse results where "success or specific-failure-reason" is the natural shape. State machines where invalid transitions should be compile errors, not runtime panics.

**The workaround:** Interface-based sum types (sealed interface with unexported method). It's verbose and the compiler still won't check exhaustiveness, but it prevents invalid values. For critical state machines, consider code generation (go generate + a tool that generates exhaustive switch statements).

### 5. Error Handling Strategy -- The Three Strategies

Dave Cheney's GopherCon 2016 talk ranks three error strategies. The ranking is the judgment -- most Go code uses the wrong one.

**Sentinel errors** (`io.EOF`, `sql.ErrNoRows`): Create coupling between packages. The caller must import your package to compare errors. They become part of your API contract -- you can never change them without breaking callers. They also carry a hidden performance cost on hot paths -- see topic 31 for DoltHub's benchmarks showing `errors.Is()` with wrapping is ~400x slower than boolean returns.

**Error types** (`*PathError`, `*SyntaxError`): Better than sentinels -- callers can extract structured information. But they still create API coupling. Any field you expose becomes a contract.

**Opaque errors** (behavior-based inspection): Cheney's preferred strategy. "Assert errors for behavior, not type" -- check `Temporary()`, not `== io.EOF`. Maximum decoupling. The caller doesn't know your error type, only what it can do.

**The judgment in practice:** Use sentinels sparingly and only at package boundaries where the caller legitimately needs to branch (EOF, not-found). Never on hot paths. Use error types when callers need structured data from the error. Default to opaque errors returned through `fmt.Errorf` with `%w` wrapping.

### 6. Error Wrapping -- Wrap at Boundaries, Return Bare Within

When your error wrapping chain is 5 levels deep and every level adds "failed to X:", the log line is useless: `failed to process request: failed to validate order: failed to check inventory: failed to query database: connection refused`. The first three "failed to" add zero information.

**The rule:** Wrap with context at package/module boundaries where the caller doesn't know what you were doing internally. Return bare errors within a package where the caller already has context. Harsanyi's 100 Go Mistakes #49: wrapping makes the wrapped error part of your API contract -- don't wrap if you won't maintain that contract.

**The corollary:** Handle an error exactly once. Harsanyi's #52: "Handling an error twice" is the most common violation. If you log the error, don't also return it. If you return it, don't also log it. The function that decides what to do about the error is the one that logs it.

**The signal:** Your error messages read as a natural sentence when printed: `reading config /etc/app.toml: open: no such file or directory`. Each layer adds the "what I was doing" context, not "an error happened."

### 7. Composition via Embedding -- When It's a Trap

Go uses embedding for composition, not inheritance. But embedding promotes all methods of the embedded type to the outer type, which creates two traps that aren't obvious until production.

**The backwards-compatibility trap (Nigel Tao, 2024):** When you embed a stdlib type, upgrading Go can silently add methods to your type via promotion. A real bug: `bug.Gray` embedded `image.Gray`. When Go 1.18 added `SetRGBA64` to `image.Gray`, `bug.Gray` automatically gained that method -- but it skipped required `SetBraille` logic, silently breaking the package. Tao's recommendation: never embed types you don't fully control.

**The JSON marshaling trap:** Embedding `time.Time` makes the outer struct implement `json.Marshaler` via promotion -- silently uses `time.Time.MarshalJSON()` and ignores all other fields. The struct serializes as a time string instead of a JSON object with all fields.

**The receiver trap:** When an embedded type's method is called, it receives the embedded type's receiver, not the outer type. Unlike inheritance in Python/Java, there's no polymorphic dispatch. The embedded method has no idea it's embedded.

**The rule:** Embed types you own and fully understand. Wrap (field + explicit delegating methods) types from external packages. The extra method forwarding is boilerplate that protects you from silent breakage.

### 8. Make the Zero Value Useful -- Where It Breaks Down

`sync.Mutex` is usable without initialization. `bytes.Buffer` works as zero value. This principle is one of Go's most distinctive design choices. But it has clear limits.

**Where it breaks:** Maps -- assignment to a nil map panics; requires explicit `make()`. Channels -- nil channel blocks forever on send/receive (sometimes useful for disabling a select case, usually a bug). Optional fields -- can't distinguish "not set" from "set to zero" without a pointer or separate boolean. API versioning -- adding a boolean field to an existing struct defaults all instances to `false`; is that the right default?

**The nil vs empty slice distinction:** `var s []T` (nil) and `s := make([]T, 0)` (empty, non-nil) behave identically for `append`, `len`, `range`, and most operations. They differ in JSON marshaling: nil -> `null`, empty -> `[]`. If you're building JSON APIs, this matters. Harsanyi's 100 Go Mistakes #22.

**The smell:** You're adding an `Init()` method to every struct. Go's zero-value principle should guide your design -- if a struct can't be useful at zero value, consider whether a constructor function (`NewFoo()`) is the right pattern, and make the zero value explicitly invalid (returning errors on use) rather than silently broken.

---

## Concurrency -- Go's Superpower and Footgun

### 9. Goroutine Lifecycle -- The One Rule

Dave Cheney: "Never start a goroutine without knowing how it will stop." Peter Bourgon names goroutine lifecycle management as "the single biggest cause of frustration faced by new and intermediate Go programmers."

A production case study: a service grew from 1,200 goroutines / 2.1 GB RAM at week 1 to 50,847 goroutines / 47 GB RAM at week 6, with p99 latency reaching 32 seconds. No crash, no panic -- just gradual memory growth until the service became unusable. Root cause: missing `cancel()` calls on WebSocket close, `time.Ticker` without `Stop()`, unclosed channels. Three converging leaks, each individually minor, collectively catastrophic.

**The pattern:** Every `go func()` needs an answer to three questions: (1) What signal tells this goroutine to stop? (2) Who sends that signal? (3) What happens if the signal is never sent? If you can't answer all three, you have a leak. Use `errgroup`, `run.Group`, or at minimum context cancellation with a documented stop mechanism.

**The smell:** `go func()` without a corresponding `cancel`, `close`, or `Stop` within 10 lines. A goroutine with an infinite loop that only exits on process termination. Test output showing `goleak` violations.

### 10. Channels vs Mutexes -- The Proverb Is About Design

"Don't communicate by sharing memory; share memory by communicating" is a design philosophy, not a performance recommendation. Benchmarks consistently show: mutex ~0.8 ns/op vs channel ~60 ns/op -- roughly 75x difference. Channels involve goroutine scheduling, queue management, and context switching. A mutex is a single atomic operation.

**When mutexes win:** Protecting per-struct invariants (a map guarded by `sync.RWMutex`). Hot paths where lock contention is low. Any case where "lock, read/write, unlock" is the complete operation. Most concurrent data structures.

**When channels win:** Signaling between goroutines (done channels, cancellation). Pipeline architectures where data flows through stages. Fan-out/fan-in patterns. Orchestration -- coordinating when things happen, not protecting what's accessed.

**The real-world pattern:** Combined use is idiomatic at scale. Channels orchestrate work distribution between goroutines; mutexes protect per-struct state within each goroutine. Using channels to protect shared state (the concurrent map pattern: 118 lines via channels vs 51 lines via mutex) is usually over-engineering.

**The signal:** You're passing data through a channel that only has one sender and one receiver, and both are in the same function. That's a mutex with extra steps.

### 11. Context -- Request-Scoped Data vs Service Locator

The context package exists for cancellation propagation and request-scoped values that cross API boundaries. The debate is about `context.Value` specifically.

**Legitimate uses:** Trace IDs, request IDs, authenticated user identity -- data that originates at an HTTP request boundary and needs to flow through the call chain without every function signature knowing about it. These are transport-level concerns, not business logic inputs.

**Illegitimate uses:** Database handles, loggers, configuration, feature flags. Peter Bourgon's criticism (2016): passing application dependencies through `context.Value` makes dependencies invisible, untraceable, and impossible to enumerate at compile time. The Go blog responded with "Contexts and structs" (2021) essentially agreeing: "it's better to pass [dependencies] as struct fields rather than as context values."

**The judgment:** If removing the value from context would change the function's behavior (not just observability), it should be an explicit parameter. If removing it would only affect logging/tracing/metrics, context is appropriate.

### 12. errgroup vs WaitGroup

Raw `sync.WaitGroup` requires manual `Add`/`Done` pairing (off-by-one = deadlock or panic), doesn't propagate errors, and doesn't support cancellation. `errgroup` (golang.org/x/sync/errgroup) wraps WaitGroup with error handling and context cancellation. Harsanyi's 100 Go Mistakes #73: "Not using errgroup."

**When WaitGroup is still right:** Fire-and-forget goroutines where you need to wait but don't care about individual errors. Background cleanup tasks. Cases where error handling is per-goroutine (each goroutine handles its own errors internally).

**When errgroup wins:** Any fan-out where the first error should cancel remaining work. HTTP handlers spawning parallel backend calls. Batch processing where partial failure means overall failure. `SetLimit(n)` on errgroup replaces the common bounded-worker-pool boilerplate entirely.

**The signal:** You're writing WaitGroup + a mutex-guarded error slice + manual context cancellation. That's errgroup with extra steps and more bugs.

### 13. Closure Capture in Goroutines -- The Four Patterns

Uber's published research (PLDI 2022) identified ~2,000 data races across their Go codebase in six months. Four structural patterns cause most of them -- all involving closure capture:

**1. Transparent reference capture:** Go captures free variables by reference (unlike Java's capture-by-value). A goroutine accessing a variable from the enclosing scope shares it with the parent -- both read and write the same memory with no synchronization.

**2. Loop variable capture:** `for _, item := range items { go func() { process(item) }() }` -- all goroutines see the same `item` variable, which advances as the loop progresses. Go 1.22 fixed this for `for` loops specifically, but the general pattern (capturing any variable that mutates after goroutine launch) remains a trap.

**3. `err` variable reuse:** Go's idiomatic `err` reuse across multiple calls becomes a data race when goroutines are introduced. The parent goroutine's `err` is shared with child goroutines.

**4. Named return variable capture:** Named return variables are accessible by goroutines launched in the function, creating races between the goroutine writing the return value and the function returning.

**The fix is always the same:** Pass the variable as a goroutine argument (`go func(item Item) { ... }(item)`) to capture by value. Or restructure so the goroutine doesn't share mutable state with its parent.

### 14. The Race Detector's Blind Spots

The race detector catches data races that execute during a test run. It cannot catch: races in untested code paths, races that only manifest under production load patterns, deadlocks, livelocks, or logical race conditions where synchronization exists but is semantically wrong.

**The overhead problem:** Memory 5-10x, execution 2-20x. This makes always-on production use impractical. Races that pass development testing persist in production. Uber's experience: ~2,000 races found in their 50-million-line monorepo even with extensive testing. PR-time detection was impractical due to non-determinism -- they use periodic snapshot analysis instead.

**Go's deadlock detector is equally limited:** It fires only when *every* goroutine is asleep. In production HTTP servers, network pollers and signal handlers keep at least one goroutine alive, so the detector never fires -- even when hundreds of business-logic goroutines are permanently blocked.

**The practical response:** Run tests with `-race` in CI (non-negotiable). Use `goleak` in tests to catch goroutine leaks. Accept that the race detector is necessary but not sufficient -- design for correctness (clear ownership, minimal sharing) rather than relying on runtime detection.

### 15. When Goroutines Are the Wrong Tool

Goroutines are cheap to start (~2-8KB stack). This makes it tempting to use them for everything. But "cheap to start" doesn't mean "free to manage."

**Sequential is correct when:** The operations have data dependencies (each step needs the previous result). The total latency is dominated by one operation (parallelizing the others saves 5% total). The code runs in a request handler where the request context already provides the concurrency boundary.

**Goroutines add value when:** You have genuinely independent I/O operations (parallel HTTP calls to different backends). You need fan-out/fan-in. You have long-running background work separate from request processing.

**The concrete test:** Will adding goroutines reduce wall-clock time by more than the complexity cost of managing their lifecycle, error propagation, and synchronization? If the answer is "maybe 10ms on a 200ms request," the goroutine isn't paying for itself.

**The smell:** A function spawns 3 goroutines to do work that takes 1ms total. The goroutine scheduling overhead exceeds the work being parallelized.

### 16. sync.RWMutex -- When the Read Lock Makes Things Worse

The intuition: "reads don't conflict, so RWMutex should be faster than Mutex for read-heavy workloads." This is often wrong. RWMutex has higher per-operation overhead than Mutex because it must track active readers, handle writer starvation prevention, and manage additional atomic operations. Under high write contention or short critical sections (read a field, release), Mutex is faster.

**When RWMutex wins:** Many concurrent readers, rare writers, AND the read-side critical section is long enough that the reader-tracking overhead is amortized. A configuration cache read by 100 goroutines and written once per minute -- RWMutex wins clearly.

**When Mutex wins:** Short critical sections (a few field reads/writes). Moderate write frequency. Any case where the lock is held for less than ~100ns -- the overhead of RWMutex's reader tracking exceeds the benefit of concurrent reads.

**The smell:** You replaced `sync.Mutex` with `sync.RWMutex` "because it's read-heavy" without benchmarking. Profile with `pprof` -- if `sync.(*RWMutex).RLock` appears in your flamegraph, the reader tracking overhead is visible and plain Mutex might be faster.

### 17. context.WithTimeout Inherited Deadline Trap

Passing a context with an already-short deadline to a function that creates a child `context.WithTimeout(ctx, 30*time.Second)` doesn't extend the deadline -- the shorter of the two wins. A parent context with 2 seconds remaining produces a child that also has 2 seconds, regardless of the 30-second timeout you specified.

**The production scenario:** An HTTP handler has a 5-second request timeout. It calls three backend services sequentially. Each creates `context.WithTimeout(ctx, 10*time.Second)`. The third call gets 1 second remaining (5s total minus ~4s for the first two calls), fails with "context deadline exceeded," and the error message references the 10-second timeout that never actually applied.

**The fix:** Check `ctx.Deadline()` before creating a child timeout to understand what's actually available. For operations that genuinely need a timeout independent of the parent, use `context.WithoutCancel(ctx)` (Go 1.21+) to detach from the parent's deadline -- but understand this also detaches from cancellation, which may not be what you want.

**The signal:** "context deadline exceeded" errors where the configured timeout seems impossibly short. The timeout you set isn't the timeout you got -- a parent's tighter deadline won the race.

---

## Interface Design -- Go's Most Powerful Abstraction

### 18. Accept Interfaces, Return Structs -- And the Real Exceptions

Jack Lindamood (2016) coined this principle. Accept interfaces to maximize caller flexibility (any implementation satisfying the interface works). Return concrete types to let callers access all methods without type assertions, and to allow adding methods without breaking the interface contract.

**The exceptions are real:**
- Factory functions that must hide the concrete type (returning an unexported struct via an exported interface)
- Functions that genuinely return different concrete types based on input
- Private functions where you control all callers and the interface adds no value

**The runtime risk of returning interfaces:** Callers who need the concrete type must use type assertions (`val, ok := result.(ConcreteType)`), which are runtime-checked. A missing comma-ok panics. Returning structs pushes this to compile time.

**The smell:** Every function in your package returns an interface. You've built a Java-style abstraction layer. In Go, concrete types are the default; interfaces are the exception at consumption boundaries.

### 19. The Bigger the Interface, the Weaker the Abstraction

Rob Pike's proverb, quantified by the stdlib: Go's standard library interfaces typically have one or two methods. `io.Reader` has one method. `io.ReadWriter` has two. `io.ReadWriteCloser` has three. `database/sql.DB` is a struct, not an interface.

**Why small interfaces are powerful in Go:** Interface satisfaction is implicit. A type satisfies `io.Reader` just by having `Read([]byte) (int, error)`. If `Reader` had 15 methods, almost nothing would satisfy it without explicit effort. Small interfaces maximize the number of types that accidentally satisfy them -- and "accidentally" is the design intent.

**When larger interfaces are correct:** When the interface represents a genuine protocol with multiple tightly-coupled operations (e.g., `http.ResponseWriter` with `Header()`, `Write()`, `WriteHeader()`). When splitting would force callers to accept three separate interfaces that are always used together.

**The smell:** An interface with 8+ methods. Ask: can a caller ever use just 3 of these? If yes, split. The Go proverb "interface{} says nothing" applies equally to interfaces with too many methods -- they say too much, locking implementations into a specific shape.

### 20. Don't Design Interfaces -- Discover Them

Jack Lindamood's "Preemptive Interface Anti-Pattern" (2016): defining an interface before a second concrete implementation exists is premature abstraction. In Go, unlike Java, you don't need to pre-declare interfaces because any type can satisfy them retroactively.

**The standard library demonstrates this:** `io.Reader` wasn't designed as an abstraction -- it emerged from the observation that files, network connections, and buffers all share the same read pattern. The interface was discovered, not designed.

**When to define an interface proactively:** At architectural boundaries where you know a second implementation will exist (production vs test, on-prem vs cloud). When the interface is part of a public API contract that external packages will implement.

**The concrete test:** Can you name two existing concrete types that would satisfy this interface? If the answer is "the real implementation and the mock" -- the interface exists for testing, which is legitimate, but be honest about it. If the answer is "just the one implementation, but we might need another someday" -- delete the interface and use the concrete type.

### 21. Consumer-Side Interfaces -- Interfaces Belong at the Callsite

In Go, the consumer defines the interface, not the producer. This inverts the Java/C# pattern where the library ships the interface and implementors conform to it. Rob Pike's "Expressiveness of Go" (2010): implicit satisfaction inverts the dependency direction.

**What this means in practice:** If your `OrderService` needs to store orders, it defines `type OrderStore interface { Save(Order) error }` in its own package -- not in the storage package. The storage package returns a concrete `PostgresStore` struct. The consumer narrows the interface to exactly what it needs.

**Why this matters:** The consumer's interface has 2 methods. The producer's struct has 20. No consumer is coupled to 18 methods it doesn't use. Different consumers can define different interfaces over the same concrete type, each seeing only what they need.

**The smell:** A `storage` package that exports `type Store interface { ... }` with 15 methods. Every consumer imports the full interface even if it uses 2 methods. Define interfaces where they're consumed, not where they're implemented.

### 22. Interface Boxing and Allocation Cost

Assigning a value to an interface variable boxes it: the runtime creates a two-word structure (type pointer + data pointer). Values larger than one machine word are heap-allocated. This means every time you pass a struct through an interface boundary, you potentially trigger an allocation that escape analysis cannot optimize away.

**When this matters:** Hot-path code processing millions of items. The `io.Reader`/`io.Writer` patterns where the interface call is in the inner loop. Profiling shows `runtime.convT` or `runtime.convTslice` as a significant cost -- that's interface boxing.

**When it doesn't:** Business logic, request handlers, anything called hundreds of times per second rather than millions. The allocation cost of interface boxing is ~20ns. At 1000 calls/sec, that's 20µs/sec -- invisible.

**The trade-off:** Interface-free code is faster but coupled. Interface-based code is flexible but allocates. Profile first. The interface boxing you're worried about is probably not in your flamegraph. If it is, consider generic functions (which can be monomorphized for value types) or accept the concrete type on the hot path.

---

## Package Design and Structure

### 23. Start Flat, Grow When Evidence Demands

Peter Bourgon: "Most of my projects still start out as a few files in package main... And they stay that way until they become at least a couple thousand lines of code." Dave Cheney: "Prefer fewer, larger packages."

**The progression:**
1. Everything in `package main` until you have concrete evidence of reuse or circular dependency pressure
2. Extract a package when you need to import it from `cmd/anothertool` or when the file count makes navigation hard
3. Split further when the package has multiple unrelated responsibilities that change at different rates

**Why this is counterintuitive for Java/Python developers:** In those ecosystems, a package/module is cheap and small (one class per file, one package per concern). In Go, a package is the unit of compilation, testing, and API surface. Creating a package creates an API boundary. Every exported symbol is a commitment.

**The smell:** You have 20 packages with 1-2 files each, half of which import each other. You've created a dependency maze. Merge the related ones into fewer, larger packages.

### 24. The "Standard Project Layout" That Isn't Standard

The popular GitHub repo `golang-standards/project-layout` claims to be the standard Go project layout. Russ Cox (Go tech lead) has explicitly said it is not official and doesn't represent the Go team's recommendations. The Go team's actual guidance is at go.dev/doc/modules/layout (published 2023), which is far simpler.

**What the official layout says:** `cmd/` for executable entry points. `internal/` for code that shouldn't be importable by external packages. That's largely it. No mandatory `pkg/`, no mandatory `api/`, no mandatory `configs/`.

**When `pkg/` is justified:** Multi-binary repos where library code is shared between binaries AND intended for external import. If everything is one binary, `internal/` is sufficient.

**When `internal/` earns its weight:** As soon as anyone outside your team imports your module. `internal/` is the compiler-enforced way to say "this is private to this module." For single-team, single-binary projects, it's often overkill -- unexported symbols already provide function-level visibility control.

### 25. Circular Dependencies and the Domain-at-Root Pattern

Go forbids circular imports at compile time. When you hit a circular dependency, the compiler isn't being difficult -- it's telling you your package boundaries are wrong. The fix is almost always: extract shared types into a root/domain package, or restructure so dependencies flow one direction.

**Ben Johnson's Standard Package Layout (2016):** Domain types at the root (no external dependencies). Subpackages are adapters (`postgres/`, `http/`). The root defines `type Order struct`, `type OrderService interface`. The `postgres/` package implements `OrderService`. `cmd/server/main.go` wires everything together -- DI at the composition root. This makes circular dependencies structurally impossible because the root depends on nothing.

**What this buys:** The root package is trivially testable (zero external deps). Swapping PostgreSQL for SQLite means replacing one subpackage. Johnson's layout, Bourgon's industrial Go, and Kat Zien's GopherCon 2018 talk all arrive at this same structure independently.

**When it's overkill:** Small services with one database and one transport. The layering adds indirection a 500-line service doesn't need. Start flat, extract when evidence demands it.

**The smell:** You're creating a `types` or `models` package to break circular deps. That's the right instinct with the wrong naming -- name the package for the domain, not the Go construct.

---

## Performance -- When "Fast Enough" Isn't

### 26. GC Tuning -- GOGC, GOMEMLIMIT, and When to Care

Go's GC defaults (`GOGC=100`) target a 2x heap overhead: if your live data is 100MB, the GC targets 200MB total heap. This works well for most services. It fails for two specific patterns.

**Pattern 1 -- Containers without GOMEMLIMIT:** Go's GC doesn't know about cgroup memory limits. A container with 512MB limit and 200MB live data will let the heap grow to 400MB, leaving only 112MB for the OS and other allocations. The OOM killer arrives without warning. Fix: `GOMEMLIMIT=90%` of cgroup limit (Go 1.19+). Harsanyi's 100 Go Mistakes #100.

**Pattern 2 -- GOGC=off with GOMEMLIMIT:** For services with predictable memory usage, `GOGC=off` + `GOMEMLIMIT=N` disables heap-growth-triggered GC entirely. The GC only runs as memory approaches the limit. This reduces GC frequency dramatically. Ardan Labs documents this pattern for Kubernetes workloads.

**When NOT to tune:** Services with unpredictable memory usage (input-proportional allocation). Environments where you don't control memory limits. If you haven't profiled, don't tune -- the defaults are deliberately conservative and correct for the common case.

### 27. Large Live Heaps and GC -- Discord and CockroachDB

Discord's Read States service experienced latency spikes every 2 minutes regardless of allocation rate. The cause: Go forces a GC cycle every 2 minutes minimum, and with tens of millions of entries in an LRU cache, the GC had to scan the entire live heap each cycle. They migrated to Rust; latency spikes were eliminated and memory usage dropped substantially.

CockroachDB's experience: Go's GC assist mechanism recruits application goroutines to help with GC when allocation rate is high. Under heavy SQL load, this causes severe tail latency -- the database is doing GC work instead of query work. Their mitigation: higher GOGC and aggressive allocation reduction throughout the codebase.

**The structural issue:** Go's GC cost is proportional to live heap size, not allocation rate. A service with a 10GB cache has expensive GC scans even if it allocates zero new objects. This is the specific workload where Go's GC model breaks down: large, long-lived in-memory data structures plus latency sensitivity.

**The judgment:** Most services don't have this problem. Stateless HTTP handlers, request-scoped processing, and small working sets are Go's sweet spot. If you're building an in-memory cache, database, or any system with a large persistent working set AND sub-millisecond latency requirements, profile GC impact early.

### 28. Escape Analysis -- What Causes Heap Allocation

The Go compiler decides stack vs heap via escape analysis. What causes heap escape: returning a pointer to a local variable, storing in an interface (boxing), sending through a channel, any value whose lifetime the compiler can't prove is bounded by the stack frame. Run `go build -gcflags='-m'` to see escape decisions.

**The practical rules:** Small structs (< ~100 bytes) -> return by value, not by pointer. The copy is cheaper than the heap allocation + GC pressure. Large structs (> ~1KB) -> pointer is justified. Need nil semantics -> pointer is required.

**The interface boxing trap:** Passing a value type through an interface boundary causes heap allocation. This means idiomatic code (using `io.Reader`, `error` interface) introduces allocation pressure on hot paths. The fix isn't "avoid interfaces" -- it's "know where your hot path is and consider concrete types there."

**The smell:** `go build -gcflags='-m'` shows "escapes to heap" on your inner loop variable, and pprof confirms `runtime.mallocgc` is a significant cost. Now you have actionable data to decide whether the interface abstraction is worth the allocation.

### 29. CGo -- "Cgo Is Not Go"

Dave Cheney's eponymous blog post (2016). The performance cliff (CockroachDB benchmarks, older Go versions): Go->C call overhead ~171 ns/op. C->Go callback ~1-2ms. Direct Go call ~1.8 ns. Go 1.21+ reduced CGo overhead to ~40 ns/op -- still 20x+ slower than a direct Go call, and you still lose Go's tooling.

**What you lose with CGo:** Static binaries (need C runtime), cross-compilation (need cross-compiler), race detector (doesn't work across boundary), pprof (can't profile C code), fuzzer, test coverage tools. The Turborepo team documented CGo's "global contamination" -- any dependency using CGo forces the entire toolchain to C-compilation mode, dramatically slowing all builds.

**Design implication:** Batch CGo calls. "Once you cross the boundary, try to do as much on the other side as you can." A function that makes 1000 CGo calls in a loop is 1000x slower than one that passes 1000 items in a single call. This fundamentally affects API design.

**When CGo is justified:** Wrapping existing, well-tested C libraries where no Go alternative exists (SQLite, image processing libraries, hardware interfaces). Never for performance -- the overhead is too high and you lose Go's tooling.

### 30. Reflection -- When Necessary, When a Disaster

Reflection (`reflect` package) has two legitimate uses: serialization (JSON, protobuf, database scanning) and generic framework code that must work with arbitrary types. Both existed before generics; generics now replace some uses.

**What reflection costs:** 10-100x slower than direct access. No compile-time type safety -- panics at runtime on type mismatches. Code using reflection is opaque to IDE navigation and code analysis. `reflect.Value` carries allocations.

**The judgment since generics:** If your "reflection-required" code operates on a known, finite set of types -- use generics instead. Generic `Map[K, V]`, generic `Filter[T]`, generic `Sort[T]` -- these were the pre-generics reflection use cases that are now better served by type parameters.

**When reflection is still correct:** `encoding/json`, `database/sql.Scan`, ORM field mapping, struct tag processing. Any code that must work with types unknown at compile time. The key: reflection at the boundary (deserialization), concrete types internally.

### 31. Sentinel Error Performance -- The Hidden Cost

DoltHub's benchmarks (2024) measured what Go's idiomatic error patterns actually cost on hot paths (relative to boolean return at 3.4 ns/op):
- Direct equality check: 7.37 ns/op (2.2x baseline)
- `errors.Is()` on sentinel: 19.35 ns/op (5.7x baseline)
- `errors.Is()` on wrapped sentinel: 1,374 ns/op (~400x baseline)
- Wrapped boolean return: 11.69 ns/op (3.4x baseline -- the wrapping overhead alone)

**Why wrapping is expensive:** `errors.Is()` walks the entire wrapping chain, calling `Unwrap()` at each level and comparing with `==`. A 5-level wrapping chain means 5 comparisons per `errors.Is()` call.

**The judgment:** For request handlers and business logic (called 100-1000x/sec), the cost is invisible -- use idiomatic errors freely. For database engines, parsers, and inner loops (called millions of times/sec), sentinel errors on the hot path are a measurable performance bug. DoltHub got "several percentage points improvement" in database throughput by eliminating sentinel error patterns. Consider boolean returns or error types with cheap comparison on genuinely hot paths.

**The pragmatic fix:** `if err != nil { if errors.Is(err, target) { ... } }` -- the nil check first avoids the `errors.Is()` walk in the happy path. Most of the cost is on the error path, which should be uncommon.

---

## Testing -- Go's Deliberately Minimal Approach

### 32. Table-Driven Tests -- When Clean, When the Table Is the Problem

Table-driven tests are Go's signature pattern: define test cases as a slice of structs, range over them with subtests. When the function under test is stateless with clear input->output mapping, this is elegant -- adding a new case is one line.

**When tables break down:** Complex per-case setup (half the struct fields are `nil` for most cases). Struct inputs longer than the test logic. Conditional fields that grow the table struct with booleans (`skipValidation bool`, `expectPartialResult bool`). Dave Cheney's observation: "Test cases getting too convoluted is a sign that the function has too many dependencies or duties."

**The alternative:** Jack Lindamood's "closure-driven tests" -- each test case is a named function with its own setup and assertions. This handles cases where different test scenarios need fundamentally different setup while keeping the subtest structure.

**The judgment:** Start with table-driven. When the table struct exceeds ~5 fields or requires per-case setup functions in the struct, consider splitting into separate test functions or switching to closure-driven. The table should make the test *easier* to read, not harder.

### 33. Test Helpers vs Frameworks -- The stdlib Reality

Go's standard library deliberately provides no assertion library. `testing.T` gives you `Error`, `Fatal`, `Log`, and subtests. The philosophy: assertions are just `if` statements, and the test failure message should describe the specific failure, not a generic "expected X got Y."

**The reality:** Most production Go projects use `testify/assert` or `testify/require`. The stdlib approach means writing `if got != want { t.Errorf("GetUser(%d) = %v, want %v", id, got, want) }` -- manual formatting, manual message composition, 3 lines per check. For large test suites, this is significant boilerplate with inconsistent error messages.

**The judgment:** For libraries and open-source code, stdlib-only tests reduce dependencies and keep the test API aligned with Go conventions. For application code with large test suites, `testify` is pragmatic -- the assertion helpers save time and produce consistent error messages. The purist position ("you don't need a framework") is technically correct and practically annoying at scale.

**What testify gets wrong:** `assert.Equal(t, expected, got)` -- the argument order is confusing (expected first, unlike Go's convention of `got, want`). Use `require` for preconditions that should abort the test, `assert` for checks where subsequent assertions are still meaningful.

### 34. Mocking Requires Interfaces -- The Design Pressure

Go cannot mock structs, only interfaces. If your code depends on `s3.Client` (a concrete struct from the AWS SDK), you cannot mock it directly -- you must either wrap it in an interface or restructure your architecture.

**This is a feature, not a bug:** The inability to mock concrete types forces you to define narrow interfaces at consumption boundaries. `type ObjectStore interface { GetObject(ctx, key) (io.ReadCloser, error) }` -- now your code depends on 1 method instead of the full S3 SDK. Your tests are simpler, your code is decoupled, and swapping S3 for GCS means implementing one interface.

**When the pressure feels wrong:** You're wrapping 15 external SDK methods in an interface just to test one function. At that point, the interface is mirroring the SDK, not abstracting it. Consider integration tests against a real (or containerized) dependency instead. Not everything needs a mock.

**The testing hierarchy:** Unit tests with interface mocks for core business logic. Integration tests with real dependencies (TestContainers, docker-compose) for adapter code. End-to-end tests for critical paths. Don't mock what you can test directly.

### 35. Benchmarks -- Writing Ones That Mean Something

Go's `testing.B` makes benchmarks easy to write and easy to write wrong. `b.ResetTimer()` exists because setup time shouldn't count. `b.ReportAllocs()` exists because allocations are often more important than wall-clock time. `b.RunParallel()` exists because single-threaded benchmarks miss contention.

**The traps:** Benchmarking a function that the compiler optimizes away (the result isn't used -- assign to a package-level sink variable). Benchmarking with `b.N` iterations without understanding that the framework varies `b.N` to reach statistical stability. Comparing benchmarks across different machines or Go versions without `benchstat`.

**The judgment:** Benchmarks are for detecting regressions and comparing implementations, not for generating absolute numbers. "This function takes 50ns" is meaningless without context. "This function takes 50ns now vs 120ns before the refactor" is actionable. Use `benchstat` (golang.org/x/perf/cmd/benchstat) to determine whether differences are statistically significant.

### 36. Golden Files and Integration Testing

Mitchell Hashimoto's GopherCon 2017 talk established golden file testing as a Go pattern: write expected output to a file, compare actual output against it, update with `-update` flag. This works well for serialization, code generation, and any output that's large and hard to express as Go literals.

**Build tags for integration tests:** `//go:build integration` separates tests that need external resources (databases, APIs) from unit tests that run anywhere. `go test ./...` skips them by default; `go test -tags=integration ./...` includes them. This keeps the default test suite fast and CI-friendly.

**`TestMain` for shared setup:** When multiple tests in a package need the same expensive setup (database migration, server startup), `func TestMain(m *testing.M)` runs once before all tests in the package. Clean up in a deferred function. This replaces test-framework-level fixtures.

---

## The "Go Way" vs Reality

### 37. stdlib vs Third-Party -- Go 1.22 Changed the Equation

Before Go 1.22, `http.ServeMux` had no method routing or path parameters. This drove the entire ecosystem of third-party routers (gorilla/mux, chi, gin). Go 1.22 added method routing (`GET /users/{id}`) and wildcard patterns, eliminating most reasons for external routers.

**When stdlib is enough (now):** Most REST-style services. The enhanced `ServeMux` handles method routing, path parameters, and precedence rules. You don't need chi for `GET /users/{id}` anymore.

**When third-party wins:** Middleware chains with complex ordering. Route groups with shared middleware. OpenAPI integration. High-performance routing with radix trees (gin). If your router needs are complex enough to benefit from a framework, the framework earns its weight.

**The broader pattern:** Go's stdlib keeps growing to absorb the most common third-party patterns. `slog` (1.21) absorbed zap/zerolog's structured logging. `ServeMux` (1.22) absorbed chi/gorilla's routing. This isn't fast -- it takes years -- but the trend means evaluating whether a third-party library is still necessary with each Go release.

### 38. Logging -- slog vs zap vs zerolog

`slog` (Go 1.21) is the standard library's structured logging package, designed after studying how zap, zerolog, and logr are used in practice. It provides a `Handler` interface that enables pluggable backends.

**The performance hierarchy:** zerolog > zap > slog in raw throughput. But slog has the fewest allocations (40 B/op, same as zerolog; zap uses 168 B/op, 3 allocs/op). For most services, the difference is invisible -- you'd need millions of log events per second to care.

**The judgment for new projects:** slog. Zero external dependencies, standard library, good-enough performance, growing ecosystem of handlers. The "but zap is faster" argument only matters if you're logging at a rate where the logging framework is in your profiling flamegraph. If it's not, slog wins on simplicity and longevity.

**The judgment for existing projects:** Don't migrate from zap or zerolog to slog unless you're already refactoring the logging layer. zap is battle-tested at Uber's scale. zerolog is proven for zero-allocation logging. Both work. The cost of migration exceeds the benefit of stdlib alignment for most teams.

### 39. Code Generation -- When go generate Is the Answer

`go generate` runs arbitrary commands and is Go's answer to metaprogramming. Common uses: protobuf code generation, SQL type generation (sqlc), ORM code generation (ent), mock generation (mockgen/moq).

**When code generation wins over generics:** When the generated code needs to be inspectable, debuggable, and type-safe without runtime cost. `sqlc` generates type-safe Go code from SQL queries -- the generated code is plain Go that the compiler checks. Generics can't express "this function returns a struct whose fields match this SQL query's columns."

**When code generation is the wrong tool:** When the generated code is large and changes frequently (regeneration noise in diffs). When the generator's output is a black box that nobody on the team understands. When hand-written code would be shorter than the generator's input configuration.

**The operational judgment:** Generated code should be committed to the repository. Requiring `go generate` as a build step makes builds depend on the generator tool being installed, versioned, and compatible. Committed generated code is reproducible and reviewable.

### 40. Functional Options vs Config Structs

Rob Pike popularized the functional options pattern for configurable constructors: `NewServer(WithPort(8080), WithTimeout(30*time.Second))`. Dave Cheney refined it. It's elegant for public APIs with many optional parameters.

**The performance cost (Evan Jones, 2023):** Functional options are slower than config structs -- each option is a closure allocation, options are applied sequentially, and the closures are less likely to be inlined. For constructors called once at startup, this is irrelevant. For builders called in tight loops, it matters.

**When functional options win:** Public library APIs where backwards compatibility matters (adding a new option is non-breaking). APIs with many optional parameters where a config struct would have 15 zero-valued fields. APIs where option validation should happen at construction time.

**When config structs win:** Internal code where you control all callers. Performance-sensitive construction. Simple APIs with 3-5 options where a struct is more readable than a chain of `With()` functions. Most application code.

**The smell:** Functional options on an internal type that has 3 callers, all in the same package. That's ceremony without benefit. Use a struct.

### 41. Map Memory Growth -- Maps Never Shrink

Go maps never release their internal bucket memory. Deleting all elements does NOT free the underlying hash table structure. The bucket count can only grow. Harsanyi's 100 Go Mistakes #28.

**The production scenario:** A cache backed by `map[string]Value` accumulates entries during a traffic spike (100K entries, significant memory). Traffic returns to normal, entries are deleted, but RSS never decreases. Over days of traffic spikes, memory grows monotonically until the service is OOM-killed.

**The fix:** Periodically recreate the map (`m = make(map[K]V)` or `m = make(map[K]V, expectedSize)`). Copy surviving entries to the new map. The old map's memory is reclaimed by GC. For cache use cases, consider an LRU implementation with bounded size instead of a raw map.

**The judgment:** If your map's maximum size is bounded and predictable, this isn't a problem. If your map grows and shrinks significantly over time, you need a recreation strategy. This is one of Go's most surprising behaviors for developers from languages where hash maps shrink automatically.

### 42. Slice Append Ownership -- The Shared Backing Array

Appending to a subslice with remaining capacity mutates the parent's backing array. `b := a[:2]; b = append(b, 99)` overwrites `a[2]` if `cap(a) > 2`. Whether this happens depends on capacity at the time of append, which is invisible at the call site. Harsanyi's 100 Go Mistakes #25.

**The defensive pattern:** Three-index slicing to cap capacity: `b := a[0:2:2]`. Now `append(b, 99)` is guaranteed to allocate a new backing array because `len == cap`. Use this whenever you create a subslice that will be appended to independently.

**The broader judgment:** Slices in Go are value types that contain a pointer. Passing a slice to a function gives the function a copy of the header (pointer, length, capacity) but shared access to the backing array. Append may or may not reallocate. This is Go's most confusing ownership semantic -- there is no "borrow" or "move" concept, just shared mutable state with non-obvious aliasing.

**The signal:** Intermittent data corruption in concurrent or sequential code that uses subslices. Tests pass with small data (backing array gets reallocated, masking the shared mutation) and fail with large data (capacity sufficient, shared mutation visible).

### 43. stdlib HTTP Server Defaults -- The Production Killers

`http.DefaultClient` has no timeout -- a well-known gotcha. The server side is equally dangerous: `http.ListenAndServe` has no `ReadTimeout`, `WriteTimeout`, or `IdleTimeout`. Slow clients hold connections open indefinitely, eventually exhausting file descriptors. Cloudflare documented hitting `"accept tcp [::]:80: accept4: too many open files"` from timeout-free production servers.

**The fix:** Always construct an explicit `http.Server` with timeouts. `ReadTimeout` bounds how long the server waits for the request body. `WriteTimeout` bounds response writing. `IdleTimeout` bounds keep-alive connections. Without these, a single slow-loris attacker can exhaust your server's file descriptor limit.

**The deeper judgment:** `http.Server.Shutdown(ctx)` waits for in-flight requests to complete; `http.Server.Close()` terminates all connections immediately (in-flight requests get TCP RST). Production servers need `Shutdown` for graceful drain, with a context timeout as a hard stop: `signal -> Shutdown(ctx) -> Close on timeout`. Most example code uses `Close`, which drops active requests.

### 44. The Error Syntax Debate Is Permanently Closed

Robert Griesemer's official Go blog post (June 2025): "For the foreseeable future, the Go team will stop pursuing syntactic language changes for error handling." The `try` proposal (2019), `check/handle` (2018), and `?` operator proposals are all dead.

**What this means for your code:** Stop waiting for `if err != nil` to get shorter. The community spent 7 years debating syntax; the team decided the boilerplate is the correct trade-off for explicit control flow. Rob Pike's "Errors are values" (2015) pattern -- using Go's full programming model to handle errors (the `errWriter` pattern) -- is the endorsed approach for reducing boilerplate, not syntax changes.

**The practical implication:** Invest in error handling patterns, not syntax complaints. The `errWriter` pattern (accumulate errors in a struct, check once at the end) works for sequential I/O operations. `errgroup` handles error collection from concurrent operations. Custom error types with methods reduce the repetitive formatting. These are the tools that exist and will continue to exist.

### 45. When to Leave Go

Go's sweet spot is infrastructure tools, network services, and CLI applications. There are specific signals that Go is the wrong choice for a problem.

**Signal 1 -- Large live heap with latency sensitivity:** Discord's migration story. If your service holds millions of objects in memory AND requires sub-millisecond tail latency, Go's GC will cause periodic latency spikes proportional to live heap size. Rust eliminates this class of problem.

**Signal 2 -- Heavy compute without I/O:** ML inference, signal processing, video encoding. Go lacks SIMD support (37% of developers familiar with SIMD report being negatively impacted -- Go Developer Survey 2024 H2). No GPU programming support. For compute-intensive workloads, Go adds nothing and its GC subtracts.

**Signal 3 -- Compile-time correctness over runtime speed:** Turborepo migrated to Rust because "the cost of each mistake is higher" for a CLI shipped to users' machines. Go's runtime error checking (nil pointer panics, type assertion failures) is acceptable for server-side where you can roll back. For distributed client software, Rust's compile-time guarantees prevent entire categories of field bugs.

**Signal 4 -- CGo contamination:** If your project requires deep C library integration, CGo's global build contamination, 170x call overhead, and loss of Go tooling make the "Go + C" combination worse than using a language with native C interop (Rust, Zig, C++ itself).

**The anti-signal:** "Go is too simple for this." Simplicity is rarely the real problem. If the actual issue is GC, compute performance, or type system expressiveness, name that. If the issue is "I want pattern matching and sum types" -- that's a preference, not a technical limitation that affects your users.

---

## Deeper Cuts -- Judgment That Only Surfaces After Years

### 46. Worker Pool Patterns -- Which One for Your Case

There are at least five ways to build a worker pool in Go. The right one depends on whether you need bounded concurrency, error collection, graceful shutdown, or all three.

**errgroup with SetLimit(n):** The simplest bounded pool. `g.SetLimit(10)` caps concurrency at 10. Each `g.Go(func() error { ... })` blocks if the pool is full. First error cancels remaining work via context. This replaces 80% of hand-rolled worker pools.

**Channel-based semaphore:** `sem := make(chan struct{}, n)` -- acquire with `sem <- struct{}{}`, release with `<-sem`. More manual than errgroup but works when you need fire-and-forget semantics without error collection.

**Persistent worker pool:** Pre-spawn N goroutines that read from a work channel. Good for long-running services where the cost of goroutine creation matters (it usually doesn't -- goroutines start in ~1µs).

**The judgment:** Start with errgroup + SetLimit. Move to a persistent pool only if profiling shows goroutine creation as a bottleneck (rare). Channel-based semaphores are for cases where errgroup's error semantics don't fit. Hand-rolling a pool with WaitGroup + channels is almost never necessary -- it's the Go equivalent of writing your own sort function.

### 47. Structured Concurrency -- run.Group and Lifecycle Management

Peter Bourgon's `run.Group` pattern pairs every goroutine with an execute function and an interrupt function. When any execute function returns, all interrupt functions are called. This gives you deterministic shutdown ordering -- the thing that `go func()` fire-and-forget lacks.

**The pattern:**
```go
var g run.Group
g.Add(server.ListenAndServe, func(error) { server.Shutdown(ctx) })
g.Add(signalHandler, func(error) { cancel() })
g.Add(backgroundWorker, func(error) { workerCancel() })
g.Run() // blocks until all actors finish
```

**Why this matters:** The alternative is hand-managing shutdown channels, WaitGroups, and cancellation functions scattered across your main function. At 3 goroutines it's manageable. At 8 (HTTP server, gRPC server, metrics server, health check, background worker, signal handler, config watcher, graceful drain) -- you need structured lifecycle management.

**errgroup vs run.Group:** errgroup is for "launch N tasks, wait for all, cancel on first error." run.Group is for "launch N long-running actors, shut down all when any one exits." Different tools for different shapes.

### 48. The errWriter Pattern -- Pike's Actual Solution to Boilerplate

Rob Pike's "Errors are values" (2015) proposes a pattern that most Go engineers cite but few actually use. The `errWriter` wraps `io.Writer`, records the first error, and silently no-ops all subsequent writes after an error:

```go
type errWriter struct {
    w   io.Writer
    err error
}
func (ew *errWriter) write(buf []byte) {
    if ew.err != nil { return }
    _, ew.err = ew.w.Write(buf)
}
```

**When it works:** Sequential I/O operations to the same destination -- writing HTTP responses, building protocol messages, serializing data. The error is checked once at the end instead of after every call.

**When it doesn't:** Operations to different destinations where you need to know WHICH operation failed. Non-I/O error chains where the "first error, then no-op" semantic doesn't apply. Any case where later operations shouldn't be skipped just because an earlier one failed.

**The broader lesson:** Go's error handling boilerplate is real, but the solution isn't syntax -- it's design. Scanner's `Scan()/Err()` pattern, bufio's `Writer.Flush()` pattern, and the errWriter all demonstrate the same idea: accumulate potential errors in state, check once at a boundary.

### 49. String Building -- Why Concatenation Kills and strings.Builder Exists

String concatenation with `+` in a loop is O(n²) because Go strings are immutable -- each `+` allocates a new string and copies both operands. For 1000 iterations with 100-byte strings, that's ~50MB of allocations for a 100KB result.

**strings.Builder:** Uses an internal `[]byte` that grows via `append` semantics (amortized O(1) per write). Final `.String()` is zero-copy -- it returns a string header pointing at the same byte slice. This is the correct tool for building strings iteratively.

**bytes.Buffer vs strings.Builder:** `bytes.Buffer` is for byte manipulation that may end as either `[]byte` or `string`. `strings.Builder` is specifically for building strings and its `String()` method avoids a copy that `bytes.Buffer.String()` must make. For string building, prefer `strings.Builder`.

**fmt.Sprintf in loops:** Also allocates per call. If you're formatting the same pattern thousands of times, consider building with `strings.Builder` + direct writes over repeated `Sprintf`.

### 50. Bourgon's Three Rules for Industrial Go

Peter Bourgon's "Go for Industrial Programming" (GopherCon EU 2018) distills production Go into three rules that experienced engineers follow instinctively:

**1. Explicit dependencies.** Every function declares what it needs in its signature. No package-level variables carrying hidden state. No global database handles. No implicit logger. Functions are honest about their inputs.

**2. No package-level variables.** This is the enforcement mechanism for rule 1. A package-level `var db *sql.DB` is a global that any function can access without declaring the dependency. Move it to a struct field. Pass it as a parameter. Make the dependency visible.

**3. No func init().** `init()` executes before `main()`, before tests, with no return value for error handling. It's untestable, order-dependent (multiple `init()` in one file execute in source order), and hides side effects. Use explicit initialization in `main()` or a constructor function.

**The payoff:** Code following these rules is trivially testable (no global state to reset between tests), deployable (no hidden environmental dependencies), and debuggable (you can trace any value to its origin through function parameters).

### 51. Dependency Management -- When to Vendor

Go modules (`go.mod`) handle dependency resolution. Vendoring (`go mod vendor`) copies all dependencies into `vendor/` in your repository. Most projects don't need vendoring.

**When vendoring is justified:** Air-gapped build environments without internet access. Regulatory requirements for dependency auditing (all dependencies must be in the repo for compliance review). Build reproducibility guarantees beyond what `go.sum` provides (the module proxy could go down or remove a module).

**When vendoring is overhead:** Most projects. `go.sum` already provides cryptographic verification. The module proxy (`proxy.golang.org`) caches modules for availability. Vendoring adds hundreds of MB to your repository, makes diffs noisy, and requires `go mod vendor` after every dependency update.

**Minimum Version Selection (MVS) implication:** Go's MVS selects the minimum version that satisfies all constraints. This means adding a dependency that requires `v1.4.0` of a shared dependency bumps you to `v1.4.0` even if you pinned `v1.2.3`. You can't cap versions. The upside: reproducible builds. The downside: your module's stated minimum is only as correct as your testing. Authors often use features from newer versions without bumping their minimum requirement -- a latent breakage.

### 52. Security Footguns in Go Parsers

Trail of Bits (2025) documented security-relevant parser behaviors in Go's standard library that create silent vulnerabilities:

**JSON tag `"-"` gotcha:** The struct tag `json:"-"` always omits a field from serialization. Developers have accidentally exposed sensitive fields (passwords, tokens) by forgetting or misspelling this tag. There's no compiler warning for a missing `json:"-"` -- it's a convention, not enforcement.

**Parser differentials:** Go's JSON, XML, and YAML parsers handle the same input differently. Content that parses successfully as JSON may parse differently as YAML, or fail entirely as XML. In systems that accept multiple formats, this differential can be exploited for access control bypass (one parser sees a field, another doesn't).

**Numeric parsing:** `strconv.Atoi` silently succeeds on `"2147483648"` (returns `int`, which is 64-bit on 64-bit platforms), but the same value overflows `int32`. Assumptions about `int` size create subtle platform-dependent bugs.

**The judgment:** Security-sensitive Go code needs parser-specific tests, not just "it parses." Test that sensitive fields are excluded from serialization. Test that the same input produces the same result across all parsers in your pipeline. Test numeric boundaries explicitly.

### 53. Mat Ryer's Evolved HTTP Patterns -- What Changed in 13 Years

Mat Ryer's "How I Write HTTP Services" has two versions: the 2018 GopherCon talk (went viral) and the 2024 update (at Grafana). The differences reveal real judgment evolution.

**What he kept:** Server struct pattern, dependency injection through constructors, `http.Handler` as the return type, middleware as function composition.

**What he dropped:** The server struct's handlers as methods pattern. His 2024 version: "that type of pattern hides dependencies and makes testing more brittle." Handlers now take dependencies as explicit function parameters.

**What he added:** Deferred expensive handler setup until first call (improves startup time). Explicit signal handling with `os.Signal` channels.

**The lesson:** Patterns evolve with production experience. A pattern that's correct for a 5-service startup is wrong for a 200-service organization. The 2018 patterns weren't wrong -- they were right for 2018's context. The 2024 update reflects 5 more years of production feedback at Grafana's scale.

### 54. The Compatibility Guarantee as API Design Discipline

Go's 13-year compatibility guarantee isn't just a language property -- it's a design philosophy you should apply to your own exported APIs. The Go team can't fix `encoding/json`'s silent handling of unknown fields because code depends on that behavior. Every exported function, type, and constant becomes a permanent contract.

**Russ Cox's framing:** "Software engineering is what happens to programming when you add time and other programmers." Your exported API is the surface area that time and other programmers interact with. Make it as small as possible.

**Practical rules:**
- Use `internal/` packages for anything whose API isn't settled
- Export functions, not types, when the caller doesn't need to know the concrete type
- Never export a struct field you might want to change -- use getter methods
- Add, don't change -- new functions are backwards-compatible, changed signatures are not
- CockroachDB's experience: 125,000 lines of non-generated Go, 600+ contributors. API discipline at this scale is what makes long-lived Go projects viable.

**The smell:** You're refactoring and every change breaks 15 external importers. Your API surface was too large from the start. `internal/` would have given you the freedom to refactor.

### 55. The Typed Nil -- Go's Billion-Dollar Corner Case

The nil-interface-vs-typed-nil mechanics are well-known. The judgment call is architectural: how do you structure code to prevent this entire class of bugs?

**The structural fix:** Functions returning `error` should never return a concrete error type. Return `error` (the interface) directly: `return nil` (not `return (*MyError)(nil)`), or `return fmt.Errorf(...)`, or `return &MyError{...}`. The bug only occurs when a function's return type is `error` but the implementation returns a typed nil pointer -- `var err *MyError; return err` where `err` is nil.

**The design rule:** Error creation and error returning are separate concerns. Create specific error types for inspection (`type NotFoundError struct{...}`). But the function's return statement should always produce an untyped `nil` or a non-nil error value -- never a nil pointer of a concrete error type.

**The test:** Run `go vet` -- it catches some cases. But the static analysis is incomplete. The real defense is the pattern: `if specificErr != nil { return specificErr }; return nil`. Never `return specificErr` when `specificErr` might be nil -- always check first.
