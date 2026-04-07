# Senior Rust Engineering Judgment

A decision framework for Rust architecture, not a checklist. Each topic is how a staff engineer thinks about the trade-off, written for a mid-level who knows the language but hasn't yet internalized when to break the rules.

---

## Ownership & Architecture

### 1. When to Clone vs Fight the Borrow Checker

The instinct is always "avoid clones." But the real question is: what's the cost of the alternative?

**Clone is the right call when:**
- The data is small (< 1KB) and the alternative is restructuring three modules to thread a lifetime through
- You're prototyping -- clone now, optimize when profiling proves it matters
- The borrow would force `Rc<RefCell<T>>` which is runtime-checked and panic-prone -- a clone is simpler AND safer

**Fight for zero-copy when:**
- The data is large or hot-path (serialization buffers, network packets)
- The lifetime naturally fits (borrowed from a long-lived owner)
- The API is public -- callers shouldn't pay for clones you could avoid

**The smell:** If you're adding lifetime parameters to 3+ structs just to avoid one clone, you've lost the trade-off. Profile first. The clone you're agonizing over is probably not even in your flamegraph.

### 2. Lifetime Complexity as Design Feedback

When lifetime annotations get hard, the compiler isn't being difficult -- it's telling you your data model is wrong. A function signature like `fn process<'a, 'b, 'c>(x: &'a Foo<'b>, y: &'c Bar<'a>)` is not a Rust problem, it's an architecture problem. You've got shared mutable references hiding behind a web of borrows.

**The senior move:** Step back and ask "who owns this data?" If the answer is "it's complicated," that's the bug. Restructure so ownership is tree-shaped: one clear owner, others get references or copies. The lifetime annotations are a symptom. When the ownership is right, the lifetimes write themselves -- usually you don't even need explicit annotations because elision handles it.

**The signal:** You're writing lifetime annotations by hand on more than two structs. Stop annotating and start redesigning.

### 3. OOP Graphs Don't Fit Rust

If you're coming from C++/Java and trying to build a graph of objects where nodes hold references to each other, you'll fight the borrow checker forever. Rust's ownership model is fundamentally tree-shaped. Cyclic references are not expressible with plain references, and `Rc`-based graphs are clunky and slow.

**What works instead:**
- **Arena + index patterns**: Store all nodes in a `Vec<Node>`, use `usize` indices as "pointers." This is what ECS frameworks do and it's cache-friendly.
- **Generational arenas** (slotmap crate): Indices with generation counters catch use-after-free at runtime without unsafe.
- **Data-oriented design**: Instead of `Node { children: Vec<&Node> }`, use `struct Graph { parents: Vec<usize>, data: Vec<NodeData> }`. Separate the topology from the data.

**The smell:** You're reaching for `Rc<RefCell<T>>` to build a graph. That's the OOP escape hatch, not a Rust pattern. Use indices. (Catherine West's RustConf 2018 talk is the canonical reference.)

`Rc<RefCell<T>>` re-introduces runtime borrow panics -- the exact bug class Rust prevents at compile time. The only defensible use is GUI frameworks with shared ownership; everywhere else, restructure.

### 4. Storing References in Structs Propagates Lifetime Cancer

The moment you put a `&'a str` in a struct, every function that touches that struct needs to know about `'a`. It propagates through your entire call chain. Three modules later, a function that has nothing to do with that string is annotated with `'a` because it transitively holds the struct.

**The rule of thumb:** If a struct outlives the scope where the reference was created -- or if you're not sure -- own the data. `String` instead of `&str`. `Vec<T>` instead of `&[T]`. The cost of ownership is one allocation. The cost of lifetime propagation is architectural complexity that makes every refactor harder.

**The exception:** Short-lived structs in a single function scope, like parser tokens that borrow from the input buffer. Those are the natural home for borrowed data in structs. If the struct crosses a function boundary, it should probably own its data.

### 5. Contagious Borrowing

Borrowing a field of a struct borrows the entire struct in the eyes of the borrow checker. If you borrow `&self.name`, you can't mutably borrow `&mut self.age` in the same scope, even though they're independent fields. The compiler sees one borrow on `self`, not two borrows on disjoint fields.

**The workaround:** Destructure into separate variables: `let Self { name, age } = self;` -- now you can borrow each independently. Or split the struct into sub-structs where the borrow boundaries match your access patterns. This is why ECS architectures separate components: each system borrows only the components it needs without blocking others.

**The signal:** You're fighting the borrow checker on `&mut self` methods that only touch one field. The fix isn't `RefCell` -- it's splitting the struct or using free functions that take individual fields as separate parameters.

---

## Error Handling Philosophy

### 6. anyhow vs thiserror

The real criterion is simple: **does your caller need to branch on specific error variants?**

- **Application code** (binaries, CLI tools, HTTP handlers): Use `anyhow`. Your caller is `main()` or a framework handler. Nobody matches on your error type -- they log it and return 500. `anyhow::Context` gives you a chain of "what was happening when this failed" that's perfect for debugging.
- **Library code** (crates others depend on): Use `thiserror`. Your caller might need `match err { MyError::NotFound => ..., MyError::PermissionDenied => ... }`. Structured errors are part of your API contract.

**The trap:** Using `thiserror` in application code because "it's more proper." You'll spend hours defining error enums that nobody ever matches on. Conversely, using `anyhow` in a library forces callers to downcast with `anyhow::Error::downcast_ref`, which is fragile and undiscoverable.

This maps to Jane Lusby's distinction: library errors are machine-readable (structured enums callers match on), application errors are human-readable (context chains operators read). Don't make one type serve both -- the adapter layer between them is where `From` impls live.

### 7. Errors Logged Where Handled, Not Where Created

Every layer adds a `log::error!` as the error passes through, and you get the same failure logged 4 times with different context. The log becomes useless noise.

**The rule:** The function that **decides what to do** about the error is the one that logs it. Every other layer propagates with `?` and adds context via `.context("what I was doing")`. If you're writing `log::error!` and then returning `Err(e)`, you're doing it wrong -- you're logging at a layer that doesn't handle the error.

**The exception:** Retry logic that wants to log each attempt before retrying. But even then, use `log::warn!` for retries and `log::error!` only for the final failure.

### 8. Error Types Must Not Leak Across Architectural Boundaries

If your HTTP handler returns `diesel::Error` to the caller, you've coupled your API layer to your database layer. When you swap Diesel for SQLx, every caller breaks. Error types are API surface.

**The pattern:** Each architectural layer has its own error type. At the boundary, you convert: `diesel::Error` becomes `repo::Error` becomes `service::Error` becomes `api::Error`. Use `From` impls or `.map_err()` at each boundary. Yes, it's boilerplate. But it's the boilerplate that lets you swap a database without rewriting your HTTP layer.

**The smell:** A `use diesel::Error` in your HTTP handler module. Or a `sqlx::Error` variant in your domain error enum.

### 9. Error Context Chains

Every `?` propagation is a chance to add context. Without it, you get `"No such file or directory"` in production. With it, you get `"failed to read config file '/etc/app.toml': failed to open file: No such file or directory"`. That context chain is the difference between a 5-minute fix and a 2-hour investigation.

**The discipline:** `.context("verb + what")` at every `?` that crosses a meaningful boundary. Not every single `?` -- you don't need context on three consecutive file operations in the same function. But at function boundaries, at module boundaries, at "what was the user trying to do" boundaries -- always.

**The anti-pattern:** `.context(format!("error in process_foo"))` -- this adds no information. The context should say **what you were doing**, not that an error happened.

### 10. Box<dyn Error> Allocation in Error Paths

`anyhow::Error` and `Box<dyn Error>` allocate on the heap. On the happy path, this costs nothing. But if errors are **expected** (e.g., validation failures on user input, cache misses, retry loops), you're allocating on every expected failure.

**When it matters:** Parsing untrusted input where 30% of inputs are invalid. Network code where connection failures are routine. Any hot loop where the error path is the common path.

**The fix:** Use a cheap, stack-allocated error type (a simple enum, or even just a `bool` for "found/not found") for expected failures. Reserve `anyhow`/`Box<dyn Error>` for unexpected failures that need rich context. The key insight: **expected failures are not errors, they're results**.

### 11. Error Type Architecture at Scale

One error enum per crate? Per module? Per function? There's no single right answer, but there are clear wrong ones.

**One enum per crate** works until the crate has 20 modules and the enum has 40 variants, most irrelevant to any given caller. **One enum per function** creates a zoo of types nobody can navigate. **The sweet spot:** one error enum per module or per domain concept. `ParseError` for parsing, `StorageError` for storage, `AuthError` for auth. Each is small enough to be matchable, specific enough to be meaningful.

**The trap at scale:** Nested error enums where `ServiceError::Storage(StorageError::Io(std::io::Error))`. Three levels of matching to handle a disk-full error. Flatten where you can: `ServiceError::DiskFull` is better than `ServiceError::Storage(StorageError::Io(...))` if the caller's response is the same regardless of which layer hit the disk-full condition.

---

## Async Judgment

### 12. Blocking I/O in Async Starves the Runtime

You call `std::fs::read_to_string` inside an async function, it blocks the tokio worker thread, and with a default runtime (one thread per CPU core), enough concurrent blocking calls freeze your entire service. It compiles. It passes tests. It fails under load.

**The rule:** Any I/O that doesn't go through tokio's reactor is blocking. That includes `std::fs`, `std::net`, and most third-party sync libraries. Use `tokio::task::spawn_blocking` to move blocking work off the async runtime. For CPU-heavy work (compression, hashing), use a dedicated thread pool -- don't even use `spawn_blocking` because it shares the blocking pool with I/O.

**The signal:** Your async service works perfectly in development and degrades catastrophically under production load. Check for blocking calls first.

### 13. Every .await Is a Cancellation Point

When a tokio task is dropped (via `abort()`, `select!`, or timeout), it's dropped at the current `.await` point. Any state mutation that happened before the `.await` is committed. Any state mutation that should happen after is lost. You get a half-mutated state.

**The concrete scenario:** `async fn transfer(from: &mut Account, to: &mut Account, amount: u64)` -- you debit `from` before an `.await`, and the task is cancelled before crediting `to`. Money vanishes.

**The fix:** Use `scopeguard::guard` to set up compensating actions. Or structure your mutations as "prepare, then commit" -- prepare the changes into a local struct, `.await`, then apply atomically. Or use database transactions that roll back on drop. The key insight: **every `.await` is a point where your function might simply stop existing**.

### 14. select! + Future Re-creation Trap

In a `loop { select! { ... } }`, if you recreate a future each iteration, it loses any buffered state. A TCP read that was halfway through a message gets restarted. A timeout that was 90% elapsed gets reset.

**The fix:** Create futures outside the loop and use `pin_mut!()` + `fuse()` to make them reusable across iterations. `fuse()` makes a completed future always return `Pending` so `select!` skips it. `pin_mut!` pins it on the stack so it survives across loop iterations.

**The smell:** A `select!` inside a loop where one of the branches calls an async function directly instead of polling an existing future. That future is being recreated every iteration and losing its progress.

### 15. std::sync::Mutex vs tokio::sync::Mutex

Use `std::sync::Mutex` when the lock guard does NOT cross an `.await` point. Use `tokio::sync::Mutex` when it does.

**Why not always use tokio::sync::Mutex?** It's slower -- it's an async-aware mutex that can yield the task, which involves waker registration and runtime interaction. `std::sync::Mutex` is a simple syscall. If you lock, read a field, unlock, and then `.await`, the std mutex is correct and faster.

**The trap:** `std::sync::MutexGuard` is `!Send`. If it's alive across an `.await`, the future becomes `!Send`, and `tokio::spawn` (which requires `Send`) refuses to compile. Clippy catches this with `await_holding_lock`. But the deeper question is: why are you holding a lock across an await at all? Usually the answer is "restructure to lock-read-unlock-then-await."

### 16. 'static Requirement on Spawned Tasks Forces Arc Everywhere

`tokio::spawn` requires `'static` because the spawned task might outlive the current scope. This means every piece of shared state must be `Arc`'d. A codebase with heavy `tokio::spawn` usage ends up with `Arc` on everything, turning Rust into a garbage-collected language with extra steps.

**The question to ask:** Do you actually need detached tasks? If the spawned work is logically scoped to the current request, you might be better off with `FuturesUnordered` or `tokio::join!` which don't require `'static`. Or use `tokio_scoped` / structured concurrency patterns.

**The signal:** More than 5 `Arc::clone` calls in a single function. You've probably over-spawned. Consider whether a `join!` or sequential execution would be simpler and fast enough.

### 17. Threading Often Beats Async

Async Rust exists to handle thousands of concurrent I/O operations efficiently. If you have 10-50 concurrent tasks that are mostly CPU-bound, `std::thread::scope` is simpler, faster, and doesn't require `'static`, `Send` on everything, or a runtime.

**The concrete scenario:** A CLI tool that processes 20 files in parallel. Async adds: a runtime dependency, `#[tokio::main]`, `Send` bounds everywhere, colored function problems. Scoped threads add: 5 lines of code and zero dependencies.

**The rule:** Use async when you have hundreds+ of concurrent I/O-bound operations (network servers, crawlers). Use threads when you have modest concurrency or CPU-bound work. The async tax (runtime, `Send`/`'static`, colored functions) is only worth paying when the concurrency level demands it.

### 18. Async at I/O Boundaries Only

**The anti-pattern:** `async fn validate_order(order: &Order) -> Result<(), ValidationError>` -- there's no I/O here, why is it async? Because it's called from an async context and the author made everything async "for consistency." Now every test of `validate_order` needs a tokio runtime.

**The senior move:** Write `fn validate_order(order: &Order) -> Result<(), ValidationError>` and call it from async code with no ceremony. Sync functions are universally callable. Async functions are not. Keep the async boundary as thin as possible.

### 19. Runtime Lock-in

Commit to tokio. async-std is effectively dead (last meaningful release was years ago). The "runtime-agnostic" approach using `futures` traits sounds principled but means you can't use `tokio::select!`, `tokio::time`, `tokio::sync`, or any tokio-specific crate -- which is most of the async ecosystem.

**The trap:** Building a library that's "runtime-agnostic" by avoiding all runtime-specific features. You'll end up reimplementing timers, channels, and select from scratch, poorly. Unless you're building foundational infrastructure (like `hyper`), just depend on tokio and ship.

**The exception:** Embassy for embedded (no-std async). And `futures::Stream` and `futures::Future` traits are genuinely portable -- use them in trait signatures. But the implementation will be tokio.

**The practical reality:** axum, tonic, reqwest (async), and sqlx are all built on tokio. Picking a different runtime means losing access to the entire stack.

### 20. Structured Concurrency

`tokio::spawn` creates a detached task. If the parent dies, the child keeps running. If the child panics, the parent doesn't know. This is Go-goroutine semantics, and it's a footgun for the same reasons.

**What to use instead:**
- `tokio::join!` / `tokio::try_join!` for fixed sets of concurrent operations
- `FuturesUnordered` for dynamic sets where you process results as they complete
- `TaskTracker` (from tokio-util) for graceful shutdown -- wait for all spawned tasks to finish
- `JoinSet` for spawning tasks and collecting results

**The smell:** `tokio::spawn` without storing the `JoinHandle`. That's fire-and-forget concurrency, and you've lost the ability to know when (or if) the task completed, or whether it panicked.

### 21. Tracing Span Propagation Across .await

When an async task is suspended at an `.await` and later resumes on a different thread, the tracing span is lost. Your logs show the span for the first half of the request and then nothing for the second half.

**The fix:** Use `.instrument(span)` from `tracing::Instrument` on every future you `.await`. Or wrap the entire async function body in a span using `#[tracing::instrument]`. The attribute macro handles this correctly.

**The subtle bug:** You create a span, enter it manually with `let _guard = span.enter()`, and then `.await`. The guard is held across the await, but the span isn't re-entered when the future resumes. Use `span.in_scope(|| ...)` for sync code and `.instrument(span)` for async code. Never use `span.enter()` in async code.

### 22. The Async/Sync Library Split

The "colored function" problem: async functions can call sync functions, but sync functions can't call async functions (without a runtime). This splits the Rust ecosystem. A sync HTTP client (ureq) can't share code with an async one (reqwest). Libraries that want to support both end up with feature flags or code duplication.

**The practical advice:** If your library does I/O, pick one (async, because the ecosystem is moving that way) and let sync callers use `block_on`. If your library is pure computation, keep it sync -- async callers can call sync functions trivially. Don't try to maintain both -- the Cargo feature unification rules make toggling between sync and async in the same binary nearly impossible.

---

## Unsafe & Soundness

### 23. Safe Code Can Break Unsafe Code

Production Rust codebases have had bugs where safe changes like field reordering or alignment changes invalidated assumptions in unsafe blocks elsewhere. The `unsafe` code assumed a specific field layout that wasn't guaranteed by repr(Rust). Safe code changes invalidated unsafe assumptions.

**The lesson:** `unsafe` blocks don't exist in isolation. Their correctness depends on invariants maintained by surrounding safe code. If your `unsafe` block assumes a field is non-null, any safe function that could set it to null makes the unsafe block unsound. The safety argument must cover **all code that could affect the invariants**, not just the unsafe block itself.

**The rule:** Every `unsafe` block needs a `// SAFETY:` comment that names the invariants it relies on. And those invariants must be enforced by the module's encapsulation -- private fields, checked constructors, sealed traits.

### 24. Incorrect Send/Sync

`Send` and `Sync` are auto-traits: the compiler derives them from the struct's fields. But the compiler can be wrong about the semantics. `MutexGuard<T>` was historically `Sync` when `T: Send`, but the correct bound is `T: Sync` -- the wrong trait bound let non-`Sync` data be shared through a guard, enabling data races in safe code (fixed in Rust 1.19, PR #41624).

**The practical risk:** If you write `unsafe impl Send for MyType {}` to silence a compiler error, you're asserting that your type is safe to send across threads. If it contains a raw pointer to thread-local storage, or an OS handle that's thread-affine, you've introduced a soundness hole that won't be caught by any test.

**The rule:** Never `unsafe impl Send` or `unsafe impl Sync` without a thorough audit of every field and every method. Prefer restructuring to eliminate the need. If you must, add a `// SAFETY:` comment explaining why each field is safe to share/send.

### 25. FFI-Heavy Rust Is a Different Language

When you're writing `extern "C"` functions, `#[repr(C)]` structs, and raw pointer manipulation, you're not really writing Rust -- you're writing C with Rust syntax. Miri can't test code that crosses the FFI boundary. `repr(C)` has platform-specific gotchas (MSVC struct packing differs from GCC). The borrow checker doesn't see through raw pointers.

**The practical advice:** Minimize the unsafe FFI surface. Write a thin `sys` crate with raw bindings, then a safe wrapper crate that enforces invariants. The wrapper crate's entire job is to make the unsafe-to-safe boundary as small and auditable as possible. Test the wrapper extensively, because no tool will verify the raw bindings.

**The tool gap:** bindgen generates correct bindings for most cases but doesn't verify ABI compatibility at runtime. cxx is better for C++ interop but adds complexity. There is no silver bullet for FFI correctness.

### 26. build.rs Is Arbitrary Code Execution

Every `build.rs` script runs at build time with full system access. A compromised dependency with a `build.rs` can exfiltrate environment variables, read SSH keys, or download malware. Typosquatting attacks like CrateDepression (2022) inject malicious code directly into crate source -- the `rustdecimal` crate impersonated `rust_decimal` and exfiltrated CI credentials. build.rs is a separate, additional attack surface: any crate with a build script can run arbitrary code even without source-level injection.

**The defenses:** Audit `build.rs` in dependencies before adding them. Use `cargo-deny` to block crates with build scripts in high-security contexts. Pin dependency versions exactly (not just `^1.0`) so a new compromised version doesn't auto-update. Consider `cargo-vet` for supply chain auditing.

**The smell:** A crate whose `build.rs` does network I/O. Unless it's downloading a C library for linking (and even then), that's a red flag.

### 27. Unsafe Is an Audit Boundary

The number of `unsafe` blocks matters less than the **surface area** of each block. One large `unsafe` block with 50 lines of pointer arithmetic is worse than five small ones with targeted, documented invariants.

**The senior approach:** Each `unsafe` block should have a small, local safety argument: "this pointer is non-null because `new()` checks it; this dereference is valid because the lifetime of the buffer is tied to `self`." If the safety argument requires understanding code in a different module, the abstraction boundary is wrong.

**The tool:** `cargo-geiger` counts unsafe usage across your dependency tree. A crate with zero direct `unsafe` but 40 transitive `unsafe` blocks isn't safe -- it's delegating trust. Know what you're trusting.

### 28. MaybeUninit Is the Only Correct Uninitialized Memory

`std::mem::uninitialized()` is deprecated and unsound -- it creates an "initialized" value with garbage bytes, which is instant UB for types with validity invariants (like `bool` or `&T`). `std::mem::zeroed()` is less bad but still wrong for most types (a zeroed `Box<T>` is a null pointer, which is UB).

**The correct tool:** `MaybeUninit<T>` explicitly represents "memory that might not contain a valid T yet." You write to it with `ptr::write` or `MaybeUninit::write`, and only call `.assume_init()` after you've guaranteed every byte is valid. This is the **only** sound way to work with uninitialized memory in Rust.

**The signal:** Any use of `mem::zeroed()` or `mem::uninitialized()` in a codebase is a finding worth investigating. Replace with `MaybeUninit`.

### 29. Pin Is Almost Always a Signal to Restructure

In library code (async runtimes, intrusive data structures), `Pin` is essential. In application code, it's almost always a sign you're fighting the ownership model instead of working with it.

**The concrete scenario:** You want a self-referential struct -- a struct that contains a field and a reference to that field. Rust doesn't allow this with safe references. You reach for `Pin` to "pin" the struct in memory so the reference stays valid. But `Pin` only prevents moves -- it doesn't make the self-reference safe. You still need `unsafe` to create it.

**The fix in application code:** Use an arena/index pattern. Store the data in a `Vec`, and where you'd have a self-reference, use an index instead. It's simpler, safe, and cache-friendly. Save `Pin` for implementing `Future` and `Stream` traits.

### 30. PhantomData Variance Matters

`PhantomData<T>` is not just "I have an unused type parameter." It controls variance and drop-check behavior, and getting it wrong can make your API unsound.

- `PhantomData<T>` -- covariant in `T`, drop check assumes you might drop a `T`
- `PhantomData<*const T>` -- covariant in `T`, no drop check (raw pointers don't own)
- `PhantomData<*mut T>` -- invariant in `T`, no drop check
- `PhantomData<fn() -> T>` -- covariant in `T`, no drop check, no ownership
- `PhantomData<fn(T)>` -- contravariant in `T`

**When this bites you:** You write a container with `PhantomData<T>` but your container uses raw pointers and doesn't actually drop `T` values. The drop checker adds unnecessary constraints on your users' lifetimes because `PhantomData<T>` implies ownership. Use `PhantomData<*const T>` instead.

**The rule:** Choose the `PhantomData` variant that matches the actual ownership and variance semantics of your type. The Rustonomicon's chapter on PhantomData is essential reading.

### 31. The Soundness Pledge Gap

Not all crates commit to the same soundness standard. Some crates have an explicit "soundness pledge" (like `zerocopy`). Others have known soundness holes that are tracked in issues but unfixed. `cargo-geiger` shows you how much `unsafe` is in your dependency tree, but it can't tell you whether that `unsafe` is correct.

**The practical approach:** For security-sensitive code, audit the `unsafe` in your direct dependencies. Use `cargo-vet` or `cargo-crev` for crowdsourced audits. Prefer crates with explicit soundness pledges, extensive Miri testing, and a track record of fixing soundness bugs quickly.

**The reality check:** You can't audit everything. Prioritize: if a crate processes untrusted input (parsers, serializers, network code) and uses `unsafe`, it gets scrutiny. If it's a dev-dependency that runs at build time, the risk profile is different.

### 32. Panic in Drop

If a `Drop` implementation panics while another panic is already unwinding, the process aborts immediately. No destructors run, no cleanup happens, the process just dies. This means `Drop` must never call fallible operations that could panic.

**The concrete risk:** `impl Drop for TempFile { fn drop(&mut self) { std::fs::remove_file(&self.path).unwrap(); } }` -- that `unwrap()` will abort the entire process if the file is already deleted. And it will happen during some other panic's cleanup, making debugging nearly impossible.

**The fix:** Ignore errors in `Drop`, or log them. `let _ = std::fs::remove_file(&self.path);` If cleanup failure is important, provide an explicit `close()` method that returns `Result` and let callers handle it. The `Drop` impl is the best-effort fallback, never the primary cleanup path.

---

## API Design Taste

### 33. Type-Level Enforcement Has a Readability Ceiling

Encoding state machines and invariants in the type system is powerful -- until the function signature is `fn process<S: State<Prev = Validated, Next = Committed>, T: Transport<Session<S>>>`. At some point, the type-level proof is harder to understand than a runtime check with `assert!`.

**The sweet spot:** Use types to enforce invariants that would be dangerous to violate (SQL injection, authentication status, unit conversions). Use runtime checks for invariants that would be inconvenient to encode (business rules, configuration validation). The test: if a new team member can't understand the type signature in 30 seconds, you've gone too far.

**The signal:** More than 3 type parameters on a public function, or generic bounds that span multiple lines. Consider whether a simpler API with a runtime check would be more maintainable.

### 34. Typestate Pattern

Encode valid state transitions at compile time. A TCP connection that goes `Closed -> SynSent -> Established -> Closed` can be modeled as separate types: `TcpConnection<Closed>`, `TcpConnection<Established>`. The `send()` method only exists on `TcpConnection<Established>`. Calling `send()` on a closed connection is a compile error, not a runtime error.

**When to use it:** Protocol implementations, resource lifecycle management (file open/closed), workflow engines. Anywhere the state machine is small (3-5 states), well-defined, and violations would be bugs.

**When to skip it:** When the state machine has 15 states and transitions are data-dependent. When the states aren't known at compile time. When the API is internal and a `debug_assert!` is sufficient. Typestate adds real API complexity -- it's worth it for safety-critical state machines, not for every enum.

### 35. Newtype for Domain Semantics

`fn transfer(from: AccountId, to: AccountId, amount: Money)` is dramatically safer than `fn transfer(from: u64, to: u64, amount: f64)`. With newtypes, swapping `from` and `to` is a type error. With raw primitives, it's a silent logic bug that passes every test where the two accounts are different.

**The cost:** Nearly zero at runtime (newtypes are `#[repr(transparent)]` and optimized away). The cost is boilerplate: you need `From`, `Display`, `Debug`, maybe `serde::Serialize`. The `derive_more` crate eliminates most of this.

**The rule of thumb:** Any ID, any measurement with units, any domain concept that "happens to be" a number or string -- make it a newtype. The compile-time safety pays for the 3 lines of boilerplate thousands of times over.

### 36. impl AsRef/Borrow for Flexible APIs

`fn process(path: &str)` forces callers with a `String` to write `process(&my_string)`. `fn process(path: impl AsRef<str>)` accepts `&str`, `String`, `&String`, and `Cow<str>` all transparently. One extra trait bound, universal callability.

**The rules:** Use `&str` not `&String`, `&[T]` not `&Vec<T>`, `&Path` not `&PathBuf`, `&dyn Trait` not `&Box<dyn Trait>`. These are the unsized coercions that make APIs flexible. For function parameters that should accept multiple owned/borrowed types, use `impl AsRef<T>`.

**The nuance:** `AsRef` vs `Borrow` -- `Borrow` has a semantic contract: the borrowed form must have the same `Hash`, `Eq`, and `Ord` as the owned form. `AsRef` is just "can give me a reference to T." Use `Borrow` for hash map keys, `AsRef` for everything else. Getting this wrong means `HashMap::get` can't find keys that are "equal" but hash differently.

### 37. The Builder Pattern

The builder pattern is often cargo-culted from Java. In Rust, if your struct has 3 fields and all are required, just use a constructor function. Builders shine when construction is **fallible** (validation across fields), **staged** (some fields set early, others late), or has **many optional fields** with defaults.

**When to skip it:** `Point::new(x, y)` doesn't need `PointBuilder::new().x(1).y(2).build()`. That's ceremony with no benefit.

**When to use it:** `HttpRequest::builder().method("GET").url(url).header("Auth", token).timeout(Duration::from_secs(5)).build()?` -- many optional fields, cross-field validation (URL required, method defaults to GET), and construction can fail.

**The typestate variant:** `Builder<NoUrl>` vs `Builder<HasUrl>` where `.build()` only exists on `Builder<HasUrl>`. This prevents constructing an incomplete request at compile time. Worth it for public APIs; overkill for internal ones.

### 38. impl Into Overuse

`fn process(value: impl Into<String>)` is ergonomic -- callers can pass `&str` or `String` without converting. But it destroys error messages: when the body of `process` has a type error, the compiler reports it in terms of `<impl Into<String>>` instead of `String`, and IDE completion on `value` shows nothing useful because the type is opaque.

**The rule:** Use `impl Into<T>` on public API functions where caller ergonomics matter and the function body is simple. Use concrete types when the function body is complex and you need readable error messages during development. Don't use `impl Into<T>` on internal functions -- the ergonomic benefit is tiny and the cost to debuggability is real.

**The related trap:** `impl Into<Option<T>>` to allow both `f(value)` and `f(None)`. This is clever and nobody understands it on first reading. Just use two functions or an explicit `Option<T>` parameter.

### 39. From Impl Proliferation

Every `From<X> for Y` is a public API commitment. It says "X can always be losslessly converted to Y." If you implement `From<u32> for UserId` and `From<u32> for OrderId`, then any `u32` silently converts to either, defeating the newtype's purpose. The `.into()` calls compile but the type safety is gone.

**The rule:** Implement `From` only for conversions that are semantically meaningful and unambiguous. If there are two reasonable interpretations of "convert X to Y," don't implement `From` -- provide a named constructor instead. `UserId::new(42)` is clearer than `42.into()` when reading code.

**The cascade:** Every `From<A> for B` gives you `Into<B> for A` for free (blanket impl). Plus `?` operator uses `From` for error conversion. So a `From` impl on your error type means any function returning your error type can `?`-propagate the source error. This is powerful but creates implicit conversion chains that are hard to trace.

### 40. Sealing Traits

A public trait that anyone can implement is an extensibility point. Sometimes that's what you want. Sometimes it's a liability -- every new impl is a new thing you have to consider when changing the trait, and downstream impls may violate invariants you assumed.

**The pattern:** Add a private supertrait: `mod private { pub trait Sealed {} }` and then `pub trait MyTrait: private::Sealed {}`. External crates can use `MyTrait` in bounds and call its methods, but can't implement it. You control all implementations.

**When to seal:** When the trait has invariants that can't be expressed in the type system (e.g., "these two methods must be consistent"). When adding a new method to the trait should not be a breaking change. When the trait is consumed, not implemented, by external code.

**When not to seal:** When the whole point of the trait is third-party extension (plugin systems, codec registries).

### 41. Cow<'a, str>

`Cow` (Clone on Write) is for APIs that are "usually borrowed, sometimes owned." A config parser that usually returns `&str` slices from the input but sometimes needs to allocate (for escape sequences) is the canonical example: `fn parse_value(input: &str) -> Cow<'_, str>`.

**When to use it:** String processing where most outputs borrow from the input. API boundaries where you don't know at compile time whether the data will be borrowed or owned. `Cow::Borrowed` is zero-allocation; `Cow::Owned` is one allocation. If you'd always be cloning anyway, just use `String`.

**When it's overkill:** Internal functions where you know the ownership at compile time. If every call path returns `Cow::Owned`, you're paying for `Cow`'s match overhead with no benefit -- just return `String`. If every call path returns `Cow::Borrowed`, just return `&str`.

**The signal:** A function that takes `String` as input, does `if condition { input } else { input.replace("a", "b") }` -- that's a `Cow` use case. You can avoid cloning on the happy path.

---

## Type System & Traits

### 42. Generics by Default, Trait Objects When Measured Need

Generics (static dispatch) should be your default. They're monomorphized: zero-cost abstraction, the compiler inlines and optimizes each concrete type. `dyn Trait` (dynamic dispatch) adds a vtable indirection, prevents inlining, and forces heap allocation (usually `Box<dyn Trait>`).

**Use `dyn Trait` when:**
- You need a heterogeneous collection: `Vec<Box<dyn Widget>>` where each element is a different concrete type
- Binary size matters: monomorphization duplicates code for each type, `dyn` shares one copy
- You're building a plugin system: concrete types aren't known at compile time

**The trap:** Reaching for `dyn Trait` because the generics "look complicated." Generics are resolved at compile time and catch errors at compile time. `dyn Trait` defers errors to runtime (object safety) and you lose type information. Take the compilation error as feedback, not a reason to switch to dynamic dispatch.

### 43. Monomorphization Bloat

Generic function `fn process<T: Serialize>(value: T)` generates a separate copy of `process` for every concrete type it's called with. If 50 types use it, you get 50 copies in the binary. This isn't theoretical -- it's why Rust binaries are larger than C and why compile times scale with generic usage.

**The fix -- inner function pattern:** Extract the non-generic core into a non-generic inner function that uses `dyn Trait`, and have the generic outer function be a thin wrapper. The outer function monomorphizes but it's one line; the inner function is compiled once.

```rust
pub fn process<T: Serialize>(value: T) {
    fn process_inner(value: &dyn erased_serde::Serialize) { /* 200 lines */ }
    process_inner(&value)
}
```

**The signal:** Binary size is unexpectedly large, or compile times are long. Run `cargo bloat --release --crates` to see which generics are bloating the binary.

### 44. Object Safety Limits

A trait can only be used as `dyn Trait` if it's "object safe." The main disqualifiers: methods that return `Self` (the vtable can't know the concrete size), generic methods (each instantiation would need a separate vtable entry), and `Self: Sized` bounds.

**The workaround:** If you need `dyn Trait` but the trait has a `fn clone(&self) -> Self` method, add `where Self: Sized` to that method to exclude it from the vtable, and provide a `fn clone_box(&self) -> Box<dyn Trait>` method instead.

**Plan upfront:** If a trait might need to be used as `dyn Trait`, design for object safety from the start. Adding `where Self: Sized` to existing methods is a breaking change for existing `dyn Trait` users. Removing generic methods is even worse. Object safety constraints should be a day-one design decision.

### 45. GATs (Generic Associated Types)

GATs allow associated types to have their own generic parameters: `type Item<'a>` in a trait. They're the answer to "streaming iterator" and "lending iterator" patterns. But in application code, they're almost never the right tool.

**When GATs are correct:** Library authors building abstractions where the associated type's lifetime or type parameter genuinely varies per method call. The canonical example is `trait LendingIterator { type Item<'a> where Self: 'a; fn next(&mut self) -> Option<Self::Item<'_>>; }`.

**When GATs are overkill:** Most of the time. If you're reaching for GATs, first ask: can I restructure ownership so the associated type doesn't need a lifetime parameter? Usually the answer is yes -- return owned data, use indices, or use a different API shape. GATs solve a real problem but the problem is rarer than you think.

### 46. Lifetime Variance

Covariance, contravariance, and invariance determine whether you can substitute one lifetime for another. `&'a T` is covariant in `'a` (you can shorten the lifetime). `&'a mut T` is invariant in `T` (you can't substitute a subtype or supertype). `Cell<T>` makes references to `T` invariant.

**When this bites you:** You write a struct `Wrapper<'a>(&'a mut Vec<&'a str>)` and the compiler won't let you use it with two different lifetimes. The `&'a mut` makes the contained `&'a str` invariant -- you can't shorten the inner lifetime independently. The fix is usually two lifetime parameters: `Wrapper<'a, 'b>(&'a mut Vec<&'b str>)`.

**The signal:** "Lifetime does not live long enough" errors on code that looks correct. Check for invariance caused by `&mut T` or `Cell<T>` holding a reference. The Rustonomicon's variance chapter is essential reading for understanding these errors.

### 47. Reborrowing

When you pass `&mut x` to a function that takes `&mut T`, Rust doesn't move the mutable reference -- it creates a temporary reborrow. This is why you can call `f(&mut x)` and then `g(&mut x)` without error. The reborrow has a shorter lifetime than the original.

**Where it breaks:** Newtype wrappers around `&mut T`. If you have `struct MyRef<'a>(&'a mut T)` and try to pass it to a function, Rust moves it (because `MyRef` is not a reference, it's a struct). You can't use `MyRef` again after passing it. The fix: implement a `reborrow(&mut self) -> MyRef<'_>` method that creates a new `MyRef` with a shorter lifetime.

**The signal:** A newtype around `&mut T` that gets "moved" when you pass it to functions, even though raw `&mut T` would work. Add a reborrow method. This is a well-known ergonomic gap in Rust -- even the standard library (like `Pin<&mut T>`) provides reborrow methods.

### 48. When to Use Enums with Data vs Separate Structs

`enum Shape { Circle { radius: f64 }, Rect { width: f64, height: f64 } }` vs separate `struct Circle`, `struct Rect` with a `trait Shape`.

**Enums with data:** When you frequently match and handle all variants together. When the variants share a common lifecycle (created, stored, processed as a unit). When you want exhaustive matching to catch missing cases.

**Separate structs:** When each variant evolves independently with different methods. When you need to add new variants without modifying existing code. When variants have very different sizes (a 10-field struct in one variant bloats the enum for all variants).

**The trade-off people miss:** Enum size equals the largest variant. If one variant is 8 bytes and another is 1KB, every instance pays the 1KB cost. `Box` the large variant or use separate structs. And if you're doing `if let Some(x) = value.downcast_ref::<ConcreteType>()` on a trait object, you've recreated a worse version of `match` -- that's a sign to use an enum instead.

### 49. Iterator Laziness Hides Side Effects

`.map(|x| { println!("processing {x}"); x * 2 })` does nothing until the iterator is consumed. If you forget `.collect::<Vec<_>>()` or `.for_each()`, the side effects never happen. The compiler warns about unused iterators, but in complex chains the warning can be missed.

**The rule:** Use iterator chains (`.map`, `.filter`, `.flat_map`) for pure transformations. Use `for` loops for side effects (I/O, mutation, logging). Mixing side effects into iterator chains is fragile -- the code is correct only if the chain is fully consumed, and refactoring might accidentally make it lazy.

**The subtle trap:** `.take(5).map(|x| db.insert(x)).collect::<Vec<_>>()` -- this inserts 5 records. Change `.take(5)` to `.take(0)` during debugging, and no records are inserted. The side effect is controlled by the iterator combinator, which is confusing. A `for` loop makes the control flow obvious.

---

## Performance Trade-offs

### 50. Arc Atomic Operations as Hidden Tax

Every `Arc::clone` does an atomic increment. Every drop does an atomic decrement (with potential deallocation). On x86 this is `lock xadd` -- a full cache-line lock. One team found 78% of their service's CPU time was spent in atomic reference count operations from pervasive `Arc` cloning in hot paths.

**When it matters:** Hot loops, per-request cloning, anything that happens thousands of times per second. `Arc::clone` is O(1) but the constant factor is significant under contention -- multiple cores doing atomic ops on the same cache line causes cache-line bouncing.

**The fix:** Clone `Arc` once at the start of a request, not on every function call. Use references within a request's lifetime. Or restructure to eliminate shared ownership -- channel-based architectures where one task owns the data don't need `Arc` at all.

### 51. Unbuffered I/O

`println!` locks stdout on every call. In a loop printing 10,000 lines, that's 10,000 lock acquisitions. Use `stdout().lock()` once and write to the locked handle. For file I/O, `File::create` gives you unbuffered I/O -- every `write!` is a syscall. Wrap in `BufWriter` for ~10x throughput.

**The pattern:**
```rust
let stdout = std::io::stdout();
let mut out = std::io::BufWriter::new(stdout.lock());
for item in items {
    writeln!(out, "{item}")?;
}
```

**The signal:** A CLI tool that's mysteriously slow when processing large inputs. Check for unbuffered I/O before optimizing algorithms.

### 52. Memory Allocator Choice

The default allocator (system malloc on Linux, MSVC heap on Windows) is general-purpose. For allocation-heavy workloads, jemalloc or mimalloc can give 5-30% throughput improvements by reducing fragmentation and lock contention.

**When to try it:** Your flamegraph shows significant time in `malloc`/`free`. You have many small, short-lived allocations (common in web servers). You're running on Linux and the default glibc allocator is known to fragment.

**The one-line change:** `#[global_allocator] static ALLOC: tikv_jemallocator::Jemalloc = tikv_jemallocator::Jemalloc;` in your binary crate's `main.rs`. Benchmark before and after. Don't use jemalloc in library crates -- the binary crate chooses the allocator.

### 53. Serde Compile Time Cost

`#[derive(Serialize, Deserialize)]` is the most expensive derive macro in the Rust ecosystem. It can add 10-30 seconds to clean builds. For a workspace with 50 crates all using serde, this adds up to minutes.

**Mitigation strategies:**
- Use `miniserde` for leaf binaries that don't need serde's full feature set (no attributes, no custom deserializers)
- Use `serde` only at boundary crates (the HTTP layer, the DB layer) and pass domain types as owned structs through the interior
- Avoid `#[derive(Serialize, Deserialize)]` on internal types that never cross a serialization boundary

**The signal:** `cargo build --timings` shows serde proc macros as the top contributor. Question every `Serialize` derive -- does this type actually get serialized?

### 54. String Types Zoo

**The mistake:** Using `String` for file paths. On Windows, file paths can contain non-UTF-8 sequences. `Path::new(some_string)` works, but `path.to_str()` can return `None`. Use `Path`/`PathBuf` for paths and handle the `Option` at the boundary where you convert to/from `String`.

### 55. usize Is Platform-Dependent

`usize` is 4 bytes on 32-bit platforms and 8 bytes on 64-bit. If you serialize a `usize` directly into a wire format, your message format is platform-dependent. A 64-bit server writing `usize` values will produce messages a 32-bit client can't deserialize.

**The fix:** Use explicit `u32` or `u64` for any value that crosses a process boundary (network protocols, file formats, IPC). Keep `usize` for in-memory indexing (which is its purpose). Convert at the serialization boundary with explicit bounds checking.

**The related trap:** `as u32` truncates silently on 64-bit platforms. Use `u32::try_from(value).expect("index fits in u32")` to catch overflow.

### 56. Cell/OnceCell/Atomics Before RefCell

Interior mutability has a hierarchy of tools, from cheapest to most expensive:

1. **`Cell<T>`** -- for `Copy` types. Zero overhead, no runtime check. `Cell<bool>`, `Cell<u32>`.
2. **Atomic types** -- `AtomicBool`, `AtomicU64`. Lock-free, thread-safe.
3. **`OnceCell`/`OnceLock`** -- write once, read many. Perfect for lazy initialization.
4. **`RefCell<T>`** -- full runtime borrow checking. Panics on violation.
5. **`Mutex<T>`/`RwLock<T>`** -- thread-safe runtime borrow checking.

**The rule:** Use the lightest tool that fits. A configuration flag that's set once and read many times? `OnceLock`. A counter? `AtomicU64`. A cache that's populated lazily? `RwLock` (or `OnceCell` if it's populated exactly once). `RefCell` is the tool of last resort for single-threaded interior mutability.

### 57. Defensive Copies Unnecessary

In C++ and Java, you defensively copy data because any other reference might mutate it. In Rust, `&T` guarantees no mutation through that reference (ignoring interior mutability). You don't need to clone data "just to be safe" -- the borrow checker guarantees no aliased mutation.

**The concrete impact:** A function that takes `&Config` can trust the config won't change during execution. No need to snapshot it. A function that takes `&[T]` can trust the slice won't be resized. This eliminates an entire class of defensive programming that's necessary in other languages.

**The exception:** Interior mutability (`Cell`, `RefCell`, `Mutex`) breaks this guarantee. If a type uses interior mutability, document it -- callers need to know they can't rely on the "shared reference means immutable" guarantee. (This is why `Cell` is called "interior mutability" -- it's the exception to the normal rule.)

---

## Generics & Macros

### 58. Declarative Macros vs Proc Macros

A `macro_rules!` macro compiles in microseconds -- it's pattern matching during parsing. A proc macro compiles an entire separate crate (syn + quote + your logic) before your main crate even starts. `syn` alone is ~5 seconds for a clean build. If you have 3 proc macro crates in your workspace, that's 15 sequential seconds before any real code compiles.

`macro_rules!` can implement DSLs, generate repetitive impls, create test helpers, and produce match arms. It's Turing-complete (via recursion). Yet most developers jump to proc macros because `macro_rules!` syntax is unfamiliar.

**What `macro_rules!` handles well:** Generating `impl Trait for Type` for a list of types. Creating test permutations. Building repetitive enum variants. Pattern-based code generation where the input is a simple list of tokens.

**What requires proc macros:** Anything that needs to inspect the structure of a type (field names, field types, attributes). Custom derive. Attribute macros that rewrite the annotated item. Anything that needs to interact with the type system.

**The smell:** A proc macro whose input is a simple list of identifiers. That's a `macro_rules!` job. Consider `paste` crate for identifier manipulation without proc macros.

### 59. Serde deny_unknown_fields vs Forward-Compatibility

`#[serde(deny_unknown_fields)]` rejects any JSON field not in your struct. This is great for catching typos in config files. It's terrible for distributed systems where different services deploy at different times.

**The scenario:** Service A adds a new field `retry_policy` to a shared message. Service B hasn't been updated yet. With `deny_unknown_fields`, Service B rejects every message from Service A. Your system is down until B is deployed.

**The rule:** `deny_unknown_fields` for local config files (where typos are the main risk). Default serde behavior (ignore unknown fields) for wire formats (where forward-compatibility is the main risk). This is the same principle that makes Protobuf ignore unknown fields by default.

### 60. Compile-Fail Tests as API Contracts

`trybuild` lets you write tests that assert certain code **doesn't** compile. This isn't just for unsafe code -- it's for any type-level guarantee your API makes.

**Examples:**
- A `NonEmpty<T>` type that prevents construction from an empty vec -- test that `NonEmpty::new(vec![])` fails to compile or returns `None`
- A typestate API where `Connection<Closed>.send()` shouldn't compile -- test it
- A sealed trait where external implementations shouldn't compile -- test it

**The value:** These tests catch regressions where a refactor accidentally makes invalid code valid. Without them, you'd never notice that your type-level safety guarantee silently disappeared.

### 61. Doc Tests Are Integration Tests

Doc tests in `///` comments compile against your crate's public API, from an external perspective. A failing doc test means your public API is broken -- not just your docs, but the actual API that users depend on.

**The hidden value:** Doc tests catch semver breakage. If you change a function signature and forget to update the doc example, the doc test fails. This is a much better semver check than most manual review.

**The cost:** Doc tests compile slowly (each is a separate binary). For large crates, run `cargo test --doc` separately from unit tests, and consider `doc-comment` crate for testing README examples without duplicating code.

**The anti-pattern:** `/// # Examples\n/// ```ignore\n/// ...``` -- ignoring a doc test. If the example can't compile, either fix the example or remove it. An `ignore`d doc test is a lie in your documentation.

---

## Build & Architecture

### 62. Compile Times Are a Productivity Tax

**The toolchain:**
- **Workspace layout:** Separate binary crates from library crates. Binary crates change often; library crates change rarely. Each library change triggers rebuilding all dependents.
- **cargo-chef:** Docker layer caching for dependencies. Dependencies are cached in a separate layer that changes only when `Cargo.lock` changes.
- **sccache:** Shared compilation cache across CI runners and developers.
- **mold linker:** 2-5x faster linking than the default `ld`. Set via `RUSTFLAGS="-C linker=clang -C link-arg=-fuse-ld=mold"`.
- **cranelift backend:** `cargo +nightly -Zcodegen-backend=cranelift build` for 20-40% faster debug builds (no optimizations).

**The signal:** More than 30 seconds for an incremental rebuild after a one-line change. Investigate with `cargo build --timings`.

### 63. Workspace Crate Splitting

Over-splitting is worse than under-splitting. Every crate boundary is a semver boundary. Moving a type from crate A to crate B is a breaking change for both crates. Re-exporting mitigates but doesn't eliminate the problem.

**The sweet spot:** Split when you have a genuinely independent unit (a client library, a proc macro, a shared types crate). Don't split "for organization" -- modules within a crate handle that. A workspace with 30 crates where each has 200 lines is worse than a workspace with 5 crates where each has 2000 lines.

**The compile time trap:** More crates means more parallelism in the build graph. But it also means more linking, more proc macro invocations, and more incremental compilation overhead. The net effect depends on your dependency graph. Measure, don't assume splitting will speed up builds.

### 64. Cargo Features Are Additive-Only

Features can only add capabilities, never remove them. If crate A enables feature "serde" on crate C, and crate B enables feature "no-serde" on crate C, Cargo enables **both** features. There's no way to say "these features are mutually exclusive." Feature unification is additive.

**The consequence:** You cannot have a feature that disables functionality. `default-features = false` in one dependent is overridden if any other dependent uses `default-features = true`. The feature matrix is the union of all features requested by all dependents.

**The trap:** Defining features "std" and "no_std" as toggles. If anyone in the dependency tree enables "std", the no_std variant is gone. Instead, make "std" additive: the crate works without "std" by default, and "std" adds additional functionality. This is the pattern used by serde, rand, and most mature crates.

### 65. cfg Matrix Explosion

Every `#[cfg(target_os = "...")]` and `#[cfg(feature = "...")]` doubles the number of code paths. With 5 features and 3 target OSes, you have 2^5 * 3 = 96 possible configurations. Most are never tested.

**The fix:** Push platform differences behind trait abstractions: `trait FileSystem { fn read(&self, path: &Path) -> io::Result<Vec<u8>>; }` with platform-specific implementations. The business logic uses the trait and doesn't know about `cfg`. The `cfg` surface is confined to one module.

**For features:** Minimize the feature surface. Don't feature-gate individual functions -- feature-gate entire modules. Test the full feature powerset in CI with `cargo hack --feature-powerset check`.

### 66. Builds Not Reproducible by Default

Rust binaries embed file paths in panic messages (`thread 'main' panicked at 'index out of bounds', /home/user/project/src/main.rs:42:5`). Different build directories produce different binaries. This breaks reproducible builds and leaks developer filesystem paths.

**The fix:** `--remap-path-prefix` strips or remaps the paths. Set `RUSTFLAGS="--remap-path-prefix $(pwd)=."` in CI. For full reproducibility, also pin the Rust toolchain version, the target platform, and all dependency versions.

**Why it matters:** Reproducible builds are a supply chain security requirement. If you can't reproduce a binary from source, you can't verify that the binary you're running matches the source you audited.

### 67. Unused Code Detection Stops at Crate Boundaries

Within a single crate, `#[warn(dead_code)]` catches unused functions. But a `pub fn` in a library crate is never flagged as unused, even if nothing in the workspace calls it. The compiler assumes external crates might use it.

**The consequence:** Public APIs accumulate dead code invisibly. You add a `pub fn helper()` for another crate, then refactor, and the helper is now unused -- but no warning fires. Over time, the crate's public surface grows with dead code that increases compile time and maintenance burden.

**The fix:** `cargo-udeps` detects unused dependencies. For unused public functions, there's no perfect tool -- periodic manual audit or custom lints. Minimize `pub` visibility: use `pub(crate)` for items used within the crate, `pub(super)` for items used within the parent module.

### 68. Transitive Dependency Cost

Adding one crate to your `Cargo.toml` might add 50-200 transitive dependencies. Each dependency is compile time, audit surface, and supply chain risk. `reqwest` alone pulls in ~100 dependencies.

**The calculus:** Is the functionality worth 100 dependencies? For an HTTP client in a web service -- probably yes. For a CLI tool that makes one API call -- maybe `ureq` (minimal dependencies) is the better choice. For parsing a date string -- `time` (few dependencies) over `chrono` (more dependencies, though chrono has been getting leaner).

**The tools:** `cargo tree` shows the dependency graph. `cargo tree -d` shows duplicated dependencies (different versions of the same crate). `cargo deny` enforces dependency policies. Before adding a dependency, run `cargo tree -i new-crate -e no-dev` to see what it pulls in.

---

## Ecosystem Judgment

### 69. Pre-1.0 Crates Are Semver Risk

A crate at version `0.x` makes no semver stability promise. `0.3.0` to `0.4.0` can (and routinely does) break every API. This is by design -- the `0.x` range is for iteration.

**The practical impact:** Depending on `rand = "0.8"` means `cargo update` will never pull `0.9` (Cargo treats `0.x` minor bumps as breaking). But if you have two dependencies that need different `0.x` versions of the same crate, Cargo can't unify them -- you get two copies, which doubles compile time and may cause type incompatibilities.

**The judgment call:** Pre-1.0 is fine for application code (you control when to update). It's risky for library code (your users might be locked to a different `0.x` version). For libraries, prefer 1.0+ dependencies or commit to re-exporting the pre-1.0 crate's types so your users don't depend on it directly.

### 70. std Has More Than You Think

- **`std::collections::BinaryHeap`** -- priority queue, no need for external crate
- **`std::sync::OnceLock`** -- lazy static initialization (stabilized in 1.70, replaces `once_cell` for many uses)
- **`std::cell::LazyCell`** -- lazy initialization for single-threaded contexts (stabilized in 1.80)
- **`std::hint::black_box`** -- prevent compiler from optimizing away benchmarks (stabilized in 1.66)
- **`std::array::from_fn`** -- initialize arrays with a closure
- **`std::iter::successors`** -- generate sequences from a seed

**The rule:** Search the std docs before reaching for a crate. The standard library grows with each Rust release, and features that once required `once_cell`, `lazy_static`, or `itertools` are now in std.

---

## Attribution

Key influences on the judgment in this document: Catherine West (RustConf 2018, data-oriented design), Jane Lusby (error handling philosophy), Armin Ronacher (API design metrics), Niko Matsakis (async design, borrow checker semantics), Jon Gjengset (Crust of Rust, intermediate Rust patterns), Alice Ryhl (tokio team, async best practices), Gankra / Aria Desires (Rustonomicon author), Mara Bos (Rust Atomics and Locks), the Rust API Guidelines working group, and the Microsoft Pragmatic Rust Guidelines team.
