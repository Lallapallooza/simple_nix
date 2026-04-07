# Senior C++ Engineering Judgment

A decision framework for C++ architecture, not a checklist. Each topic is how a staff engineer thinks about the trade-off, written for a mid-level who knows the language but hasn't internalized when to break the rules.

This is universal C++ -- not tied to std:: or any single ecosystem. The judgment applies whether you're writing LLVM, Unreal, embedded firmware, Google-scale services, or a Bloomberg trading system. The first question is always "which C++ are you writing?"

---

## Which C++ Are You Writing?

### 1. The Dialect Question

There is no single "C++." There are at least five dialects with incompatible assumptions:

- **Modern/STL-idiomatic:** auto, ranges, smart pointers, exceptions, structured bindings. What textbooks teach.
- **Systems/LLVM-style:** No exceptions, no RTTI, custom ADTs, llvm::Error, explicit over clever.
- **Game engine (Unreal/EASTL):** Custom allocators, custom containers, no exceptions, no virtual in hot paths.
- **Embedded/MISRA:** No heap, no exceptions, no RTTI, no recursion, static allocation only.
- **Legacy:** Macros, raw new/delete, C++98 constraints, decades of accumulated decisions.

Applying advice from one dialect to another causes harm. Before writing a line of code, identify which dialect you're in and why the rules exist. The rules aren't arbitrary -- they flow from constraints (real-time budgets, ABI stability, binary size, compile time, team discipline). The Core Guidelines assume exceptions-everywhere, but over half of production C++ disables exceptions (2018 isocpp survey, cited in P0709R4). Entire sections of the guidelines don't apply to those codebases.

**The smell:** You're applying "modern C++ best practices" to a codebase that builds with `-fno-exceptions -fno-rtti`. Those "best practices" assume features your project has deliberately disabled.

### 2. When C-Style Is Correct in C++

Carmack's Doom 3 engine used "C with classes": no exceptions, minimal templates. He values code that fits on one screen, doesn't break the debugger, and can be understood top to bottom. This isn't ignorance -- it's deliberate.

C-style is correct when: you're at a C API boundary (extern "C"), every reader must understand the code without knowing template metaprogramming, or the abstraction hides what the hardware actually does. A `memcpy` into a known-layout buffer is clearer than constructor chains when writing a network protocol parser. What you give up: RAII, destructor safety, type-checked generics. The trade-off is real in both directions.

**The signal:** The code does exactly what it says, in the order it says it. No implicit conversions, no hidden control flow, no destructor ordering surprises.

### 3. When "Modern" Makes Things Worse

Aras Pranckevičius (Unity graphics lead, 2018) documented that including `range-v3` for a trivial operation expanded preprocessing from 720 to 102,000 lines, compiled over 3x slower than all of SQLite (220k lines), and ran 150x slower in debug builds. This isn't a ranges bug -- it's the cost of heavy template machinery in any debug configuration where the optimizer can't inline everything away.

Your developers spend most of their time in debug builds. A feature that "optimizes away at -O2" is fully present at -O0: every template instantiation executes, every inline function is a real stack call, every RAII wrapper runs its constructor and destructor without elision. The pattern repeats: concepts improve error messages but don't fix compile-time explosion. Constexpr moves computation to compile time but adds to compile time.

Stroustrup's P0977 paper "Remember the Vasa!" warns C++ is accumulating features without integrating them into a coherent whole. The practical judgment: don't use a feature because it exists. Use it because it solves a specific problem better than the alternative you already understand. A raw `for` loop compiles instantly, debugs perfectly, and every C++ programmer alive can read it.

**The smell:** A code review introduces a C++20/23 feature nobody else on the team has used, for a problem already solved with established patterns. Or: "but it optimizes away" -- ask: in debug builds? Across TU boundaries? At ABI boundaries?

---

## Ownership & Lifetime

### 4. RAII -- When It Matters

RAII is non-negotiable for resources: file handles, mutex locks, network connections, heap allocations. But RAII for an 8-byte stack struct with trivial destruction is ceremony. The judgment is about granularity: RAII at the resource level, not the value level. If the destructor does nothing meaningful, the wrapper earns nothing.

**The signal:** Your RAII types correspond 1:1 to actual resources -- things that can leak, be double-freed, or fail to be released.

### 5. Smart Pointer Hierarchy

The hierarchy: automatic storage (stack) first, then `unique_ptr` for heap-allocated single ownership, then raw non-owning pointers or references for observation, and `shared_ptr` only when ownership is genuinely shared -- which is rare.

Raw pointers are correct and idiomatic for non-owning observation. The Core Guidelines say `T*` is non-owning (R.3). A function receiving `T*` or `T&` says "I use this but don't control its lifetime." That's legitimate. `unique_ptr` has a real ABI cost: Carruth demonstrated it must be passed on the stack (27 assembly lines) rather than in a register (19 lines for a raw pointer) due to its non-trivial destructor.

When you reach for `shared_ptr`, ask: "why can't I identify a single owner?" Usually the answer reveals unclear lifecycle or tangled dependencies -- a design problem, not a pointer problem. `shared_ptr` is ~2x slower than raw `new`/`delete` due to atomic reference counting on every copy, even single-threaded. Under contention, atomics bounce cache lines across cores. Legitimate uses: plugin systems, observer patterns with uncontrolled lifetimes, truly shared concurrent data. If you can explain the shared ownership in one sentence, it's probably legitimate.

**The smell:** `shared_ptr` everywhere because "it's safer." It's not -- it's a de facto global variable with atomic overhead and unpredictable destruction timing.

### 6. Arena Allocation -- The Bulk Ownership Pattern

When many objects share a lifetime (a parse tree, a compilation phase, a request, a frame), arena allocation -- bump a pointer, free everything at once -- is an order of magnitude or more faster than individual `new`/`delete` and eliminates fragmentation.

LLVM's `BumpPtrAllocator` is the canonical example: clang's entire AST is arena-allocated. Google's Protobuf uses arena allocation per-request. Game engines use per-frame arenas. The constraint: objects can't be individually freed, and non-trivial destructors don't run automatically. This is a feature -- it forces you to think about lifetime as a batch, which is often the correct model.

**The smell:** Every object wrapped in `unique_ptr` or `shared_ptr` when all of them will be freed at the end of a clearly-defined phase. Per-object overhead for per-batch lifetime.

### 7. Rule of Zero -- and the Value/Entity Decision

If your class doesn't directly manage a resource, don't write any special members. Let the compiler generate them. Rule of Five is the escape hatch for resource wrappers -- small, focused types like `FileHandle` or `SocketWrapper` that isolate resource management. Everything else follows Rule of Zero.

The prerequisite: decide whether your type is a value (copyable, comparable, independent -- like `int`, `string`, `Point3D`) or an entity (unique identity, non-copyable -- like `thread`, `file_handle`). Value types should be regular in Stepanov's sense: two copies are equal and independent. Entity types should be move-only. Getting this wrong cascades -- value semantics on an entity produces double-free; entity semantics on a value forces unnecessary heap allocation. If your type is copyable but `copy(a) != a`, it will silently corrupt any sorted container.

**The signal:** You can count your Rule-of-Five types on one hand. Everything else compiles with `= default` for all special members.

### 8. View Types Are Parameter-Only

`std::string_view`, `std::span`, LLVM's `StringRef` -- these are borrow types. They reference data they don't own. Storing them as data members or returning them from functions creates dangling pointers that ASan catches but code review often misses.

Arthur O'Dwyer's rule: `string_view` is a parameter-only type. Use it in function parameters and range-for loop control variables. Never store it. Never return it from a function that constructs the underlying string. The same applies to `span<T>`: the moment the owner reallocates (`vector::push_back`), every span is dangling.

**The smell:** A struct with a `string_view` member. Ask: who owns the data this views? What guarantees the owner outlives this struct? If the answer involves "well, in practice..." -- store a `string`.

### 9. No Destructive Move -- The Moved-From Tax

C++ move leaves the source in a "valid but unspecified" state. Unlike Rust's destructive move, the moved-from object must still be destructible -- the destructor runs, checking for null/zero state. `unique_ptr` passed via `std::move` requires stack storage, move, then destruct-the-null-source.

For small-buffer-optimized types (short strings, small functors), move copies the same bytes as copy -- the data lives inline, nothing to steal. Scott Meyers documented: "adding a single character to a string can increase the speed of moving it by a factor of three" because it flips from inline to heap.

**The signal:** When writing a move constructor, think about what state the source needs for its destructor. If you can't make it cheaper than a copy, don't pretend move is an optimization.

---

## Abstraction Design

### 10. Type Erasure -- Polymorphism Without Inheritance

Sean Parent's "Inheritance Is The Base Class of Evil" (GoingNative 2013): runtime polymorphism does not require inheritance. The three-component pattern -- Concept (abstract interface), Model<T> (wraps any concrete type), Owner (value semantics, holds Model by pointer) -- achieves polymorphism where types don't inherit from anything. `std::function` and `std::any` are standard-library examples. MLIR's `OpInterface` uses this pattern instead of virtual inheritance.

The advantage: duck typing with static type safety, copyable objects, no base class pointers, no slicing. The cost: one heap allocation per polymorphic object (mitigable with SBO), more setup boilerplate than virtual. Best when the set of operations is stable but the set of types is open-ended.

When inheritance IS correct: fixed interface with virtual dispatch AND genuine is-a hierarchy AND runtime polymorphism at call sites where the type is unknown. When the set of types is fixed, `std::variant` with `std::visit` wins instead.

**The signal:** You can add a new type to a polymorphic collection without modifying existing code and without the type inheriting from anything.

### 11. Templates vs Virtual -- The Real Trade-off

Templates: zero runtime dispatch, full inlining, but code bloat per instantiation, longer compiles, and page-spanning error messages. Virtual: one indirect call (~3-10 cycles in hot loops), no bloat, but blocks inlining.

The judgment matrix:
- **Hot loop, few types, known at compile time:** Templates or CRTP. Virtual adds branch predictor pollution per iteration.
- **Plugin boundary, unknown types, loaded at runtime:** Virtual dispatch. Templates can't cross shared library boundaries.
- **Cold path, readability matters:** Either works. Pick whichever is clearer.

Compilers are increasingly good at devirtualization: marking a class `final` can halve virtual dispatch cost. Don't assume virtual is slow without measuring.

**The smell:** Templates everywhere "for performance" on code called once per user interaction. Virtual everywhere "for flexibility" with exactly two concrete types.

### 12. CRTP vs Concepts

CRTP injects base class members without virtual dispatch: `class Derived : public Base<Derived>`. C++20 concepts replace CRTP for pure constraint checking -- they constrain without injecting, don't force inheritance, and produce readable error messages.

But CRTP still wins for mixin injection -- when the base adds methods or data to the derived class. Concepts can constrain; they can't inject.

**The signal:** CRTP only to constrain a template parameter? Replace with a concept.

### 13. Policy-Based Design -- Library Tool, Not Application Tool

Alexandrescu's policy-based design is zero-overhead customization: `template<class ThreadingPolicy, class AllocationPolicy> class SmartPtr`. Each policy is inlined completely. No virtual dispatch. Appropriate for library code serving diverse use cases. Inappropriate for application code where policies are known at design time.

The compile cost: each unique combination generates a new type. Error messages without concepts are brutal. Debugging through policy indirection is painful.

**The smell:** A class has 4 template policy parameters but the codebase only ever instantiates one combination.

### 14. When to Bypass std::

LLVM replaces `std::vector` with `SmallVector<T,N>` (avoids heap for <=N elements), `std::unordered_map` with `DenseMap` (open addressing, cache-friendly), `std::string` with `StringRef`. EASTL, Abseil, Folly, and BDE all replace significant parts of the standard library.

The reason is consistent: std:: optimizes for generality, not your specific workload. Use std:: by default. Replace when profiling shows it's the bottleneck AND you understand exactly which trade-off hurts. "It might be faster" is not a reason. "Profiling shows 40% of time in hash table lookups, DenseMap's open addressing reduces misses 3x" is.

### 15. std::function Heap-Allocates

`std::function` performs type erasure -- heap allocation for callables larger than its small buffer (typically 16-24 bytes). Alternatives: template parameters (zero overhead but viral), function pointers (zero overhead, no captures), `llvm::function_ref` (non-owning callable reference, like `string_view` for functions).

**The judgment:** `std::function` for callbacks registered once and called rarely. Templates or function pointers for anything called per-element, per-frame, or per-message.

### 16. Hidden Friends -- The Underused Interface Technique

Defining a non-member function (operators, swap) as a `friend` inside the class body makes it invisible to normal lookup -- only findable via ADL when one argument is the class type. Benefits: smaller overload set (faster compilation, shorter errors), prevents implicit conversions triggering unexpected resolution.

Most engineers define operators as members (preventing symmetric conversions) or as free functions in the namespace (bloating overload sets). Hidden friends are the sweet spot.

**The signal:** Your `operator==` is a `friend` inside the class. It only participates in resolution when an argument is actually your type.

### 17. The Zero-Cost Abstraction Myth

Carruth's CppCon 2019: "There Are No Zero-Cost Abstractions." `std::unique_ptr` -- often cited as zero-cost -- can't pass in a register at ABI boundaries because of its non-trivial destructor (27 assembly lines vs 19 for raw pointer). Templates cost compile time and binary size. Virtual costs branch prediction. RAII costs destructor ordering. Raymond Chen (2022): "Zero-cost exceptions aren't actually zero cost" -- compilers must spill state before potentially-throwing operations.

The question is never "is this zero-cost?" but "where does the cost appear, and does it matter here?" Inside a single TU with optimization, many abstractions disappear. Across TU boundaries, at ABI boundaries, in debug builds -- the costs are real.

**The signal:** You choose an abstraction and can name exactly where its cost appears and why it's acceptable.

### 18. Abstraction Timing

In C++, a wrong abstraction is uniquely expensive to undo. A premature template propagates through headers, bloats compile times, and generates page-spanning errors. A premature base class locks in virtual dispatch, heap allocation, and pointer indirection for every consumer.

Copy-paste three similar functions. When the fourth arrives and you see the stable pattern, extract. The cost of duplication is bounded (fix a bug in three places). The cost of a wrong abstraction grows with every user who adds a parameter to work around it.

**The smell:** A template class has more template parameters than the duplicated code had lines. A base class has one derived class and has had one for three years.

---

## Error Handling

### 19. The Ecosystem Split

There is no universal error handling strategy. The split is principled:

- **Exceptions:** Zero happy-path cost (unwind tables), catastrophically expensive when thrown. Best when errors are rare and call depth is high. Banned in Google, LLVM, game engines, embedded, safety-critical.
- **Error codes / absl::Status:** One branch per call level. Best for moderate error frequency with deterministic timing.
- **Result types (llvm::Error, std::expected):** Same branch cost but type-safe and harder to ignore. `llvm::Error` aborts if destroyed unchecked.

The crossover: exceptions faster than error codes when error rate is below ~1:1000 and call depth above ~100. Error codes win when errors are frequent or the chain is shallow. But the choice is rarely about performance -- it's about determinism, binary size (unwind tables add 2-15%), optimizer constraints (compilers can't reorder across try/catch), team discipline (exception safety requires RAII-all-the-way-down), and C interop (exceptions can't cross `extern "C"` boundaries).

**The signal:** Your error strategy matches your ecosystem's constraints. You can explain in one sentence why you chose it.

### 20. LLVM's Error/Expected -- Making Errors Impossible to Ignore

`llvm::Error` aborts if destroyed without being checked -- even on the success path. `llvm::Expected<T>` is `Either<T, Error>`. This solves the fundamental problem: `bool success()` looks the same as `bool hasValue()`. Nothing stops you from using a status as a value.

The design rules: library code uses `Error`/`Expected<T>` and never calls `exit()`. Command-line tools use `ExitOnError`. Programming errors use `assert`/`llvm_unreachable`, not error returns. This pattern directly influenced `std::expected<T,E>` in C++23 -- but `std::expected` doesn't enforce checking. LLVM's version does.

**The smell:** Functions return `bool` or `int` for success/failure, and callers discard the return value.

### 21. noexcept Is a Permanent Contract

`noexcept` is not just a performance hint -- it's an API promise you can never remove. `vector` reallocation uses `move_if_noexcept`: without `noexcept` on your move constructor, vector silently falls back to copying. Marking `noexcept` today and removing it tomorrow silently degrades every vector holding your type.

The other side: marking everything `noexcept` because "it doesn't throw right now" is a trap. A future refactor that adds a throwing call inside a `noexcept` function produces `std::terminate` -- not a compilation error, a runtime kill.

**The judgment:** `noexcept` on: destructors (always), move operations (always), swap (always), simple getters. Off: anything that might evolve to include allocations, IO, or calls to code you don't control.

### 22. Error Types Are API Surface

If your HTTP handler returns `diesel::Error`, you've coupled your API to your database. When you swap databases, every caller breaks. Each layer should have its own error type. At boundaries, convert: database error -> repository error -> service error -> API error.

**The smell:** A `#include` of an implementation library's header in your public API, just to expose its error type.

---

## Performance Reality

### 23. Data Layout and Cache

Mike Acton (CppCon 2014): "The purpose of all programs is to transform data." Cache misses -- not algorithmic complexity -- dominate runtime on modern CPUs. `std::vector` with linear search outperforms `std::set` (O(log n)) for small-to-medium sizes because every comparison is a cache hit. A linked list wastes ~87% of each cache line on pointer overhead.

Array-of-structs (AoS) vs struct-of-arrays (SoA): if you iterate a million entities but touch only `position` and `velocity`, AoS wastes bandwidth loading every other field. SoA fetches only what you need, and SIMD autovectorization works on SoA but can't work on AoS. The game industry's ECS shift is fundamentally AoS->SoA.

**The judgment:** DOD applies to batch processing: game loops, physics, data pipelines, compiler passes. Not to GUI code, business logic, or prototypes. AoS is the default for clarity; SoA for measured hot paths.

### 24. Move Semantics -- When Move Pessimizes

`std::move` on a return statement prevents NRVO (Named Return Value Optimization). The compiler was going to construct directly in the caller's space -- zero copies, zero moves. `std::move` forces an actual move instead. Don't write `return std::move(local);` -- just `return local;`.

For SSO strings (typically <=22 characters), move copies the same bytes as copy -- nothing on the heap to steal. Meyers: "adding a single character to a string can increase the speed of moving it by a factor of three" because it transitions from inline to heap.

**The judgment:** Trust the compiler for return values. Use `std::move` only when explicitly transferring ownership of a named variable you won't use again AND you're not in a return statement.

### 25. Compile Time Is a Design Constraint

Pranckevičius: a trivial `range-v3` usage compiled over 3x slower than all of SQLite. Bruce Dawson (Google) documented template instantiation avalanches. LLVM mandates `#include` minimization. At Google scale, compile time determines developer productivity more than any other technical factor.

Header-only libraries trade integration simplicity for compile-time cost: every TU compiles the entire implementation. For small utilities, fine. For Boost.Asio, you're recompiling a framework in every file. Compiled libraries require build system integration but keep compile times bounded.

**The signal:** You know the compile time of your heaviest TUs and have profiled why they're slow. Header-vs-compiled decisions are based on measured impact.

### 26. constexpr -- Power with Compile-Time Cost

`constexpr` moves computation from runtime to compile time: lookup tables, hash functions, configuration -- resolved by the compiler, embedded as constants. The runtime cost is zero.

The compile-time cost is not zero. `constexpr` functions must be visible in headers (compiler needs the definition). For small computations, excellent trade-off. For generating large lookup tables, consider build-time codegen (Python script, cmake custom command) instead.

**The signal:** Your `constexpr` computations take milliseconds. If constexpr evaluation is significant in compile time, use codegen instead.

---

## Concurrency

### 27. Lock-Free Is Not Automatically Faster

A well-implemented mutex (`futex` on Linux) has ~20-50ns uncontended overhead. Lock-free wins only under HIGH contention with SHORT critical sections. Under low contention, a mutex is faster, simpler, and provably correct.

The real cost of lock-free: correctness is extremely hard. Memory ordering mistakes are silent on x86 and catastrophic on ARM. A lock-free queue that "works" on your dev machine and corrupts data in production on Graviton is a standard failure mode.

**The judgment:** Start with a mutex. Profile. If contention is measurable AND the critical section is short AND you have team expertise in memory ordering, consider lock-free.

### 28. Memory Ordering -- seq_cst by Default

`memory_order_seq_cst` (the default) provides global ordering. On x86 (TSO), it's often free -- the hardware already provides it. On ARM/POWER, it inserts barriers.

`relaxed` provides only atomicity -- no ordering. Safe for standalone counters. Dangerous for anything coordinating state. Hans Boehm (Google, P2135): "A Relaxed Guide to memory_order_relaxed" -- titled ironically; the content catalogs subtle mistakes even experts make.

**The signal:** `seq_cst` everywhere. `acquire`/`release` only for producer-consumer with a correctness proof. `relaxed` only for standalone counters and statistics.

### 29. False Sharing -- The Invisible Slowdown

Two independent atomic variables on the same 64-byte cache line cause cache-coherency traffic when accessed by different cores. Each write invalidates the other core's line. Benchmarks show 2-8x degradation in typical cases -- more under heavy contention.

Fix: `alignas(std::hardware_destructive_interference_size)` to place hot variables on separate cache lines. A 4-byte `atomic<int>` now occupies 64 bytes. Correct for per-thread counters, work-stealing queue heads, and any atomic hot on multiple cores.

**The smell:** Two `atomic` variables adjacent in a struct, accessed by different threads. Adjacent in memory = same cache line = false sharing.

### 30. x86 Lies to You

x86's strong memory model (TSO) means code with weak orderings often "works" because the hardware provides guarantees the programmer didn't ask for. ARM and POWER have weak models: loads and stores reorder freely. Code that relies on TSO silently produces wrong results on ARM -- no crash, no warning, just corrupted data.

Sutter's "atomic Weapons" (C++ and Beyond 2012): program to the C++ memory model (weak), not x86 (strong). In 2026, ARM means phones, servers (Graviton), Macs (M-series), and embedded. If your code may ever run on ARM, test on ARM.

---

## API & Physical Design

### 31. ABI Stability vs Clean Design

C++ has no guaranteed stable ABI across compiler versions. This forces a choice: freeze your class layout (ABI stability for binary distributors) or accept that consumers rebuild (Google's "live at head" model).

The committee has rejected ABI-breaking improvements repeatedly. Carruth's `unique_ptr`-in-register problem is unfixable without an ABI break. `std::regex` is notoriously slow but can't be replaced. GCC 5's `std::string` change (COW to SSO for C++11) required a dual ABI that still exists in 2026 -- mixing old and new binaries crashes because `sizeof(string)` changed. Use `const char*` or `string_view` at shared library boundaries to avoid depending on your users' standard library ABI.

For library authors: ABI stability is essential -- use pImpl, avoid exposing data members. For application developers: rebuild from source and ignore ABI. Abseil explicitly promises API stability but NOT ABI stability.

### 32. Physical Design -- The Include Graph Is Architecture

Lakos (*Large-Scale C++ Software Design*, 1996): which files include which files is a first-class engineering discipline. Cyclic include dependencies create systems that can't be tested incrementally, compiled in parallel, or understood locally.

The unit of physical design is the component (`.h`/`.cpp` pair). Dependencies must form a DAG. Bloomberg's BDE implements this at scale. LLVM enforces strict include hygiene. The payoff: bottom-up testing, component extraction, parallel compilation.

**The signal:** You can build any component and its transitive dependencies in isolation. Adding a `#include` is a conscious design decision.

### 33. pImpl -- Compile-Time Firewall

The public class holds `unique_ptr<Impl>`, all data members live in the `.cpp`. The header is stable across implementation changes. Cost: every call adds pointer indirection (not inlineable without LTO). Construction requires heap allocation. "Fast pImpl" uses fixed-size aligned storage to avoid the heap.

Essential for SDK and library authors maintaining binary compatibility (Qt uses it pervasively). Overkill for application-internal classes that rebuild together.

### 34. [[nodiscard]] as API Design

Louis Brandy's Facebook talk: ignorable return values are a systematic bug source. `std::async` returns a future whose destructor blocks -- discarding it blocks the calling thread at the semicolon.

`[[nodiscard]]` on every function returning a status, error code, result, or handle. Zero runtime cost. Nobody can accidentally ignore a failure.

---

## Syntax Traps

### 35. Initialization Syntax -- The Absurd Complexity

C++ has four initialization syntaxes (`T x = v;`, `T x(v);`, `T x{v};`, `T x = {v};`) that behave differently: `{}` prevents narrowing but triggers `initializer_list` overloads; `()` allows narrowing but doesn't. `auto x{42}` deduced `initializer_list<int>` in C++11/14 but was changed to `int` in C++17.

Abseil Tip #88 documents the differences. Pick one convention for your codebase: commonly `{}` for initialization (prevents narrowing), `()` where `initializer_list` ambiguity exists (`vector<int>(5)` -- five elements, not a list containing 5).

**The smell:** All four syntaxes used inconsistently. Each has different implicit conversion rules; mixing means different constructors fire for visually similar code.

### 36. The Most Vexing Parse

`Timer timer();` doesn't create a `Timer` -- it declares a function. Brandy's Facebook talk showed this still causes real bugs at scale. The variant he documented: `unique_lock<mutex>(m_mutex);` -- this declares a local variable named `m_mutex`, doesn't lock the mutex. Compiles, runs, does nothing.

Fix: `Timer timer{};` or `unique_lock lock(m_mutex);` with CTAD. Name your RAII objects.

### 37. Structured Bindings and Lifetime

`auto [a, b] = getStruct();` copies the returned struct -- `a` and `b` bind to the copy's members. `auto& [a, b] = getStruct();` is a dangling reference if `getStruct()` returns by value -- the temporary dies at the semicolon. `const auto& [a, b] = getStruct();` extends the temporary's lifetime.

The asymmetry between `auto&` (dangling) and `const auto&` (lifetime-extended) is a documented production bug. In range-for loops: `for (auto [k, v] : map)` copies each pair; `for (const auto& [k, v] : map)` doesn't.

### 38. Signed/Unsigned at Container Boundaries

`for (int i = 0; i < container.size(); i++)` -- signed/unsigned comparison warning that hides real bugs. The STL uses `size_t` (unsigned), so `i - 1` when `i` is `size_t` and equals 0 wraps to `SIZE_MAX`. This is a documented CVE source in bounds-checking code.

The judgment: use `size_t` or `ptrdiff_t` for indices into containers. Use `std::cmp_less` (C++20) for mixed-sign comparisons. Don't silence the warning with a cast -- fix the types.

---

## Production Patterns

### 39. Recurring Bugs Need Enforcement, Not Education

The same C++ bugs recur regardless of how good engineers are. `std::map::operator[]` inserts on missing keys, iterator invalidation after `push_back`, structured bindings that copy instead of reference. Brandy documented these at Facebook scale: education doesn't fix them. Automated enforcement does.

Specific clang-tidy checks that matter: `bugprone-use-after-move`, `performance-unnecessary-copy-initialization`, map subscript misuse, missing `noexcept` on move operations. The investment in static analysis pays for itself after the first production bug prevented.

**The signal:** Your CI runs static analysis on every commit. You don't rely on reviewers to catch mechanical bugs.

### 40. UB Means "The Compiler Assumes This Can't Happen"

Undefined behavior is not "it might crash." It's "the compiler may assume this code path is unreachable." Signed overflow is UB -> the compiler eliminates a bounds check depending on `x + 1 > x` (assumes always true). Null dereference is UB -> the compiler eliminates a null check after a dereference.

John Regehr: "Compilers exploit UB aggressively and will do so more in the future." A program with UB doesn't have a bug in one place -- it has no defined behavior anywhere. Manifests as "works in debug, wrong in release" because the optimizer makes more aggressive assumptions at higher levels.

### 41. Sanitizers Belong in CI

ASan, UBSan, and TSan catch bugs no amount of testing or review finds: use-after-free on cold paths, signed overflow in edge cases, data races under specific timing. They have false negatives: `shared_ptr` cycles undetected, use-after-move undetected (use clang-tidy for that). A clean sanitizer run is a floor, not a ceiling.

**The judgment:** ASan + UBSan on every CI run. TSan nightly or per-PR for concurrent code. The 2-3x slowdown is what CI is for.

### 42. RTTI Alternatives

LLVM builds with `-fno-rtti` and implements its own: `isa<T>`, `cast<T>`, `dyn_cast<T>`. These check a `Kind` enum -- single integer comparison -- instead of `dynamic_cast`'s vtable chain traversal. Faster, more predictable, works without `-frtti`.

The pattern -- discriminator enum in the base, `classof()` static in each derived -- applies to any closed hierarchy where you know all types at compile time. `dynamic_cast` is fine for occasional checks in non-hot code. For type dispatch in tight loops, LLVM-style is an order of magnitude faster.

### 43. ODR Violations Are Silent and Lethal

The One Definition Rule: every symbol must have exactly one definition across all translation units. Violations -- same class defined differently due to different `#define`s or different includes -- produce undefined behavior with zero diagnostic from most compilers.

Common cause: a header conditionally defines a class member based on a macro that differs across TUs. Each TU sees a different `sizeof(Foo)`. Linking succeeds; the program silently corrupts memory because code compiled with different layouts accesses the same object. Clang's `-Wodr` and Gold linker's `--detect-odr-violations` are the only defenses.

**The smell:** `#ifdef` inside a class definition in a header. Different TUs may compile with different macro definitions, seeing different class layouts.

### 44. Static Initialization Order Fiasco

Global/static object construction order across TUs is undefined. A global `Logger` in `logging.cpp` that depends on a global `Config` in `config.cpp` may observe an uninitialized `Config` if `logging.cpp`'s initializers run first.

Fixes: the Meyers singleton (`static T& instance() { static T t; return t; }` -- construction on first use, thread-safe since C++11), `constinit` (C++20, guarantees compile-time initialization), or eliminating globals entirely. LLVM's coding standards ban static constructors -- `clang -Wglobal-constructors` enforces this.

**The smell:** A mysterious crash or wrong behavior that only happens on some platforms or with some link orders. The root cause is a global depending on another global that hasn't been constructed yet.

### 45. C++20 Modules -- Not Ready (2026)

The standard says modules are the future. The tooling says: not yet. MSVC, Clang, GCC all support modules but each has bugs. CMake support (3.28+) breaks on complex builds. Ubuntu prior to 26.04 shipped broken module metadata. One production report (2025): removing modules made builds 15% faster. Mixing `#include` with `import std` causes link failures on MSVC.

**The judgment:** Don't adopt for production unless validated with YOUR compiler, build system, and dependency set. Plan for them -- they will eventually be right. But "eventually" is not 2026 for most shops.

### 46. Coroutines -- Powerful but Viral

C++20 stackless coroutines are viral: any function that suspends must be a coroutine, and all callers must handle the coroutine return type. This propagates through the entire codebase. The boilerplate is significant: `promise_type`, handle management, `co_await`/`co_return` machinery.

**The judgment:** Coroutines for IO-heavy code where the alternative is callback hell. Not for general async where a thread pool works. Introduce at architectural boundaries (network layer, file IO), not pervasively.

### 47. Ranges -- Expressiveness vs Performance

`std::ranges` provides composable, lazy, declarative data processing. Excellent for clarity and correctness. Daniel Lemire (2025) measured ranges as slower than hand-written loops in production JSON parsing on GCC. Google's Chromium team documented concerns about correctness with borrowed ranges, compile time, and readability.

**The judgment:** Ranges for data transformation where clarity matters. Hand-written loops for inner loops where every cycle counts.

---

## The STL Question

### 48. The Allocator Model Is Broken

The STL's allocator model is per-type, not per-instance. You can't have two `vector<int>` using different allocators of the same type. EA's EASTL documentation calls this "the most fundamental weakness" of the standard library. EASTL, BDE, Abseil, and Folly all built custom containers partly to fix this.

**The judgment:** Default allocator is fine for most code. When you need custom allocation (arena, pool, per-thread), expect to use a library that fixed the allocator model or write allocation-aware containers yourself.

---

## The Safety Question

### 49. Memory Safety Is Structural

NSA and CISA (2022-2025) recommend against C/C++ for security-sensitive code. Mozilla attempted to parallelize their CSS style system in C++ twice, abandoned both -- the third attempt in Rust (Servo) succeeded because ownership enforcement prevented the data races that made C++ attempts unworkable. Microsoft ships Rust in the Windows kernel.

This isn't about discipline -- it's about what the language can enforce. `string_view` dangling, use-after-free, use-after-move, iterator invalidation are structural properties, not individual failures.

**The judgment:** Acknowledge the limitation. Compensate with sanitizers, static analysis, and restricted coding standards. Honestly evaluate whether new projects should use C++ or a memory-safe alternative. Migration costs are real and many projects don't have security-sensitive attack surfaces. But "C++ is fine with good practices" is also not honest.

### 50. Sutter's Safety Profiles

Herb Sutter's response: Safety Profiles (P3436, 2024). Opt-in compiler modes enforcing type safety (ban unsafe casts), bounds checking, initialization requirements, and lifetime restrictions. Target: 90-98% reduction in major CVE categories.

**The reality (2026):** No production compiler has implemented them. Cppfront experiments with some ideas but has no production adoption. The direction is credible; the tooling is nonexistent today.

### 51. const Correctness -- Documentation vs Ceremony

`const` on interfaces is critical: `void process(const Config& cfg)` tells callers their config won't be modified. `const` return types prevent accidental mutation. These are API contracts -- non-negotiable.

`const` on every local variable is ceremony. `const int x = 5;` adds a keyword that tells the reader nothing they can't see from the three-line scope. Don't fight about local const. Fight about missing const on public API parameters.

---

## Common Rationalizations

| Rationalization | Why it fails |
|---|---|
| "It's more modern" | Modern is not a synonym for better. A `for` loop is modern enough. |
| "The optimizer will fix it" | Not in debug builds, not across ABI boundaries, not without LTO. |
| "We need this for flexibility" | Name the second use case. If you can't, you're speculating. |
| "Google does it this way" | Google has 250M lines, automated refactoring tools, and constraints that don't match yours. |
| "The standard says exceptions" | The standard also says `vector<bool>` is a container. Over half of production C++ disables exceptions. |
| "shared_ptr is safe" | Memory-safe, not design-safe. Atomic overhead, unpredictable destruction, reference cycles. |
| "Use the latest standard" | Use what your toolchain, CI, and team reliably support. Modules are "in the standard" and broken. |
| "Lock-free would be faster" | Profile first. Under low contention, a mutex is faster and provably correct. |