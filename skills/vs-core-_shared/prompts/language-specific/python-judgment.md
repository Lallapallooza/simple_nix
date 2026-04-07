# Senior Python Engineering Judgment

A decision framework for Python architecture, not a checklist. Each topic is how a staff engineer thinks about the trade-off, written for a mid-level who knows the language but hasn't yet internalized when to break the rules.

---

## Architecture & Design

### 1. When to Use Classes vs Functions

The instinct from Java/C# is "everything is a class." Jack Diederich's "Stop Writing Classes" (PyCon 2012) was the correction. But dataclasses changed the equation -- a typed dataclass is a legitimate way to group related parameters, not a class-in-a-trenchcoat.

**Functions are the right call when:**
- The logic is stateless -- input in, output out, no side effects
- You're tempted to write a class with only `__init__` and one other method
- The "object" is just a namespace for related functions (use a module instead)

**Classes earn their weight when:**
- You have genuine state that persists across calls
- Multiple methods need to share and mutate that state
- The lifecycle matters (setup, use, teardown -- think context managers)

**The smell:** A class with `__init__` and one method. That's a function in a trenchcoat. But a `@dataclass` with five fields and no methods? That's a legitimate data container -- don't flatten it into function arguments.

### 2. Data Modeling: Dataclasses vs attrs vs Pydantic vs NamedTuple

The FastAPI era made Pydantic feel like the default. It's not -- Pydantic validates and coerces, and that's expensive (5-7x slower instantiation than dataclasses, ~3x more memory). The correct architecture: Pydantic at trust boundaries, dataclasses or attrs internally.

**`@dataclass(slots=True)` (Python 3.10+):** The default for internal models. Slots eliminate per-instance `__dict__` (~232 bytes each) -- at 10M instances, that's ~612MB -> ~77MB (8x reduction). Attribute access is measurably faster (direct C-struct offset vs dict hash). Zero validation overhead. mypy understands it natively.

| Scale | Without slots | With slots | Savings |
|---|---|---|---|
| 1M instances | ~1.7 GB | ~500 MB | 70% |
| 10M instances | ~612 MB | ~77 MB | 87% (8x) |

**The inheritance trap:** If a parent dataclass has fields with defaults and a child adds required fields, the auto-generated `__init__` fails -- non-default args can't follow default args. The fix is `kw_only=True` (Python 3.10+), which makes all fields keyword-only and eliminates positional ordering constraints. Without knowing this, developers "fix" it by giving everything a default of `None`, destroying type safety.

**attrs + cattrs:** When you need composable validators, custom equality, or library code that shouldn't depend on Pydantic. cattrs is ~1.7x faster than Pydantic v2 for JSON encoding -- the gap narrowed significantly with v2's Rust core. For true speed, msgspec is ~10x faster than either.

**Pydantic v2:** At system boundaries only -- API request validation, config parsing, external data ingestion. Its automatic type coercion (strings silently becoming ints, `Pendulum.DateTime` silently downcast to `datetime`) is a footgun for internal models where data is already trusted.

**NamedTuple:** Immutable records with <4 fields where tuple unpacking is useful. Beyond that, dataclass wins on readability.

**The smell:** Pydantic models in your domain layer. If the data is already validated, you're paying validation tax on every instantiation for no benefit.

### 3. Metaclasses Are (Mostly) Dead

`__init_subclass__` (PEP 487) killed 90% of legitimate metaclass use cases. Before, you needed a metaclass for subclass registration, plugin systems, or field collection. Now:

- **Subclass registration:** `__init_subclass__` with a class-level registry dict
- **Descriptor initialization:** `__set_name__` handles it without metaclass intervention
- **Field collection:** `dataclasses` and `attrs` do this better than any custom metaclass

**Remaining legitimate uses:** ORMs (`DeclarativeMeta` in SQLAlchemy), framework internals that genuinely need `type.__new__` control. If you're not writing a framework, you don't need a metaclass.

**The signal:** You're reading a metaclass tutorial. Stop. Whatever you're building, `__init_subclass__` or a decorator handles it. Metaclasses make code undebuggable for anyone who doesn't already understand metaclasses, and that's most of your team.

### 4. ABC vs Protocol: Trust-Level Routing

The textbook presents these as a hierarchy (duck typing < ABC < Protocol). They're actually tools for different trust levels:

**Duck typing:** Inside a module, between functions you control. The cost of adding Protocol annotations to private helpers exceeds the benefit.

**Protocol (PEP 544):** At module boundaries. Structural subtyping -- works with any object that has the right methods, no inheritance required. The default for new typed interface definitions.

**ABC:** When you need runtime enforcement. Plugin systems where third-party code must implement your interface and you want `TypeError` at class definition time, not at call time three stack frames deep. Also correct when you provide shared default implementations (Template Method pattern).

**The trade-off nobody mentions:** Protocol is static-only by default -- `isinstance()` checks require `@runtime_checkable`, which adds overhead and can't check method signatures. If your callers don't run mypy, ABC gives faster feedback.

**The signal:** You're reaching for Protocol but your downstream callers don't run a type checker. They'll get confusing errors at call time, not at class definition. Use ABC -- it fails loud and early.

### 5. Dependency Injection Without a Framework

Python's first-class functions make DI cheap. Pass collaborators as constructor arguments. A container class (just a dataclass with explicit construction) handles 80% of use cases.

**A DI framework earns its weight when:** Complex scoping (singleton vs factory vs thread-local), wiring decorators for auto-injection in large apps, configuration-driven object graphs. That's `python-dependency-injector` territory.

**It doesn't when:** Anything under 50 classes. The framework overhead is cognitive, not runtime -- you're adding a dependency to avoid writing 10 lines of constructor wiring.

**The smell:** A DI framework in a project with fewer services than the framework has configuration options.

### 6. The Abstraction Timing Problem

Python makes abstraction syntactically cheap -- decorators, context managers, and metaclasses are all one-liners to define. This is dangerous.

**The concrete failure mode:** Two endpoints share validation logic -> `@validate_input` decorator. Third endpoint needs different validation -> decorator gains `strict=True`. By the tenth endpoint, the decorator has 8 parameters and 200 lines. Nobody understands it. New developers copy-paste *around* it rather than through it.

**When to copy-paste:**
- The "duplicated" code serves different domains (user validation vs payment validation)
- The code is still evolving and you don't know which parts are stable
- The "abstraction" would need more parameters than the duplicated code has lines

**When to abstract:** After the third *actually identical* instance. Or when a bug has been fixed in one copy but not others -- that's the signal that abstraction pays for itself.

**The rule:** Copy-paste has bounded cost. A wrong abstraction has unbounded cost that grows every time someone adds a parameter to work around it.

### 7. Magic Methods: Protocols Yes, DSLs No

`__getattr__` and `__getattribute__` make attribute access dynamic, which means: grep finds nothing, debuggers can't resolve `obj.foo` without executing the chain, type checkers give up, and IDE "go to definition" breaks completely.

**Worth it:** `__enter__`/`__exit__` (context managers), `__iter__`/`__next__` (iteration), `__init_subclass__` (metaclass replacement), `__getattr__` for explicit proxy/delegation with documented targets.

**Not worth it:** `__getattribute__` (called on *every* attribute access, infinite recursion risk, zero legitimate application-code uses). Stacking `__getattr__` -> `__getitem__` -> `__call__` to build DSLs. `__class_getitem__` for non-generic types.

**The rule:** Magic methods implement standard Python *protocols*. If grep can't find where behavior is defined, the abstraction is too clever.

### 8. Import Architecture

**The __init__.py convenience tax:** Re-exporting everything from `__init__.py` creates a flat API but: importing any symbol loads all re-exported modules (3x slower startup), circular imports become inevitable at 10+ modules, and lazy-loading becomes impossible.

**The fix for large packages:** SPEC 1 lazy-loading pattern (used by NumPy, SciPy) with `__getattr__` on the module. PEP 810 (`lazy import foo` / `lazy from foo import bar`) targets Python 3.15 -- an explicit `lazy` keyword, not a modifier on existing imports.

**Circular import resolution priority:**
1. Import from definition files directly, not package roots
2. `TYPE_CHECKING` guard for type-hint-only imports
3. Lazy import inside functions (signals an architecture problem)
4. `importlib` for genuinely optional heavy deps

**The smell:** `from .submodule import *` in `__init__.py`. Explicitly list what you re-export. Structure `__init__.py` as a table of contents, not a loading dock.

### 9. Module-Level Side Effects and Global State

Instagram found server startup took 20+ seconds in a multi-million-line codebase because imports executed database connections, config reads, and network calls. They built "Strict Modules" to statically verify module-level code is pure.

**OK at module level:** Constants (`TIMEOUT = 30`), type definitions, logger creation (`logging.getLogger(__name__)`), compiled regexes.

**Not OK at module level:** Database connections, HTTP clients, file handles, reading env vars into globals, signal handlers, thread spawning.

**The test:** `python -c "import yourmodule"` should work without network, filesystem, or environment variables. Anything else belongs in a function called at application startup.

**The production consequence:** Module-level side effects create import-order dependencies. Test A imports module X (initializing a DB pool), that state leaks to test B. Tests pass locally (deterministic order) and fail in CI (parallel or shuffled).

---

## Type System

### 10. Gradual Typing: Start Comprehensive, Not Incremental

Dropbox's biggest regret typing 4M lines: only type-checking a subset initially. Files outside the mypy build got `Any` on import, destroying precision. Kraken reached zero missing annotations after 2.5 years and 25K annotations added.

**What works:** Enable strict on new files, permissive on old via `per-module-options`. Integrate into CI immediately -- non-blocking warnings kill adoption. Assign ownership -- Dropbox had 2 failed attempts before a dedicated 3-person team (including Guido) succeeded.

**What doesn't:** Announcing a typing initiative without enforcement. Typing prototype code with high churn. Typing dynamic patterns (plugin architectures, metaclass ORMs) where the type system hits its ceiling.

**The signal:** You don't see ROI in week one. You see it six months later when a rename propagates cleanly in 20 minutes instead of 3 days of grep-and-pray. Dropbox's team found typing paid for itself in refactoring velocity, not bug prevention.

### 11. mypy vs pyright: Run Both

mypy has the only plugin API -- the only option for codebases with ORM metaclass magic (Django, SQLAlchemy). pyright is 3-5x faster with near-instant IDE feedback. ty (Astral, Rust-based) is 20x faster but not yet production-complete.

**The practical split:** mypy in CI (plugins, reference behavior), pyright via Pylance in the editor (speed, DX). Many production teams run both.

**The trap:** They diverge on some constructs. Code passing one may fail the other. This isn't hypothetical -- 21 developers cited it as a concrete pain point in Meta's 2024 typing survey.

**The signal:** If you're fighting both checkers on the same line, the code is probably too dynamic. Simplify the code before adding `# type: ignore`.

### 12. "If Typing Is Hard, the Code Is Wrong"

Meta's survey: the top value of type annotations isn't correctness (49.8%) -- it's better IDE support (59%). But the deeper insight: **annotation difficulty is a design smell detector.**

A function that's hard to annotate usually has one of these problems:
- Returns different types depending on input (overloaded behavior hiding in one function)
- Mutates and returns (should split into two operations)
- Accepts "anything" and introspects at runtime (should be Protocol-bounded)

**The action:** When you struggle with a type annotation, don't reach for `Any` or `cast()`. Ask why it's hard. The answer is usually a design problem, not a typing limitation.

### 13. TypeVar, ParamSpec, TypeVarTuple: The Complexity Ladder

**TypeVar:** Any generic function where return type relates to input. `def first(items: list[T]) -> T` is straightforward and pays for itself in IDE autocomplete. PEP 695 (Python 3.12+) simplifies syntax dramatically.

**ParamSpec:** Only for decorators that must preserve the wrapped function's full signature. Worth it for widely-used decorators, overkill for one-offs.

**TypeVarTuple:** Variadic generics for shape-typed arrays. Justified only for numeric/tensor code where shape errors are real bugs.

**The split:** Library authors need all three. Application engineers use TypeVar occasionally, rarely touch ParamSpec, and almost never need TypeVarTuple.

### 14. Runtime vs Static Type Checking

Static checkers (mypy/pyright) catch errors at dev time but don't exist at runtime. Runtime checkers (Pydantic, beartype) catch errors in production but cost CPU. The judgment is where to draw the line.

| Layer | Tool | Cost profile |
|---|---|---|
| Static, dev-time | mypy/pyright | Zero runtime cost |
| Runtime, boundaries | Pydantic v2 | O(n) -- validates every field, every nested model |
| Runtime, hot-path | beartype | O(1) -- randomly samples one item per nesting level |
| Runtime, tests only | typeguard | Full traversal, but only in test runs |

**The concrete scenario:** You validate 10K items/sec through a Pydantic model in a loop -- 40ms overhead per batch you didn't account for. Static checks can't catch where you're doing unnecessary runtime validation. That's a design decision, not a type error.

**The smell:** `isinstance()` checks in code that's already statically typed. You're duplicating what mypy verified. The only legitimate `isinstance()` in typed code is at trust boundaries -- parsing external data.

### 15. type:ignore as Technical Debt Metric

Bare `# type: ignore` silences all errors on the line (the mechanics are well-known). The judgment call is organizational: treat `# type: ignore` count as a codebase health metric, like TODO count or cyclomatic complexity.

**The enforcement stack:** `mypy --warn-unused-ignores` in CI (catches stale ignores that accumulate after library updates). Ruff rule PGH003 flags bare `# type: ignore` without error codes. PR review should question any new ignore -- "why can't the code be fixed instead?"

**The Kraken benchmark:** Their 5M-line Django monorepo tracked ignore count as a weekly metric, reaching zero missing annotations after 2.5 years. The ignores didn't just go away -- each one represented a design decision that got revisited.

**The signal:** More than 10 `# type: ignore` in a single module. The module's design doesn't fit the type system -- refactor the module, don't paper over it with ignores.

---

## Error Handling & Configuration

### 16. EAFP vs LBYL: Neither Is Always Right

Guido explicitly stated he doesn't consider EAFP "generally recommended" over LBYL. Python 3.11 made the happy path truly free (zero-cost exception handling), but exception *raising* is still expensive.

**EAFP wins when:** Exceptions are rare (<5%), multi-threaded access (LBYL has check-then-act race), duck typing (`try: foo.method()` beats `hasattr` checks).

**LBYL wins when:** Failures are expected (validation pipelines -- 2-3x faster than catching), operations are irreversible (validate before writing), or broad exceptions could mask unrelated bugs.

**The gap:** Tutorials teach EAFP as "the Pythonic way." Engineers who've watched a data pipeline silently pass half the records before exploding know to validate first.

### 17. Exception Hierarchy Design

You have 15 exception types and every caller writes `except LibraryError` because navigating the hierarchy is impossible. That's the smell -- you designed for taxonomy, not for callers.

**2-3 levels max:** `LibraryError` -> `CategoryError` -> `SpecificError`. Always provide a root exception so callers catch everything in one clause. Inherit from `Exception`, not `BaseException`. Names end in `Error` (not `Exception`).

**Attach context as attributes:** `raise RateLimitError("limit hit", retry_after=60)` -- callers should not parse message strings. This is Python-specific: exception attributes are first-class, use them.

**The rule:** If two exception types always get caught together, they should be one type. Three levels of wrapping where the caller's response is the same regardless of depth -- flatten it.

### 18. structlog vs stdlib Logging

stdlib `logging` is sufficient if configured properly: parameterized messages (`logger.info("Widget %s", widget)`), per-module loggers (`logging.getLogger(__name__)`).

**structlog earns its keep when:** You need key-value context binding (request_id, user_id on a bound logger), logs go to ELK/Datadog/CloudWatch, or you want environment-adaptive output (pretty in terminal, JSON in containers).

structlog forwards to stdlib handlers -- it's an enhancement layer, not a replacement. The two coexist.

**The signal:** You're adding `request_id=` to every `logger.info()` call manually. That's structlog's entire value proposition -- bind context once, carry it through every log line automatically.

### 19. Context Managers vs __del__

`__del__` is not a destructor. Timing is unpredictable -- for objects in reference cycles, `gc` decides when (or if) it runs. Even after PEP 442 (Python 3.4), timing remains non-deterministic.

**The rule:** Context managers (`with`) for deterministic resource release. File handles, database connections, locks, temp files -- all belong in `with` blocks. `contextlib.contextmanager` for one-offs (3 lines vs 10 for a class). `contextlib.ExitStack` when resource count is determined at runtime.

**The signal:** `__del__` in application code. Almost always wrong. Provide an explicit `close()` method and a context manager. `__del__` is the best-effort fallback, never the primary cleanup path.

### 20. Configuration: pydantic-settings and 12-Factor Reality

The classic anti-pattern: `settings_dev.py`, `settings_staging.py`, `settings_prod.py` with `import *` chains. `DEBUG = "False"` (string) evaluates as truthy. `TIMEOUT = "30"` breaks arithmetic. Environments drift silently.

**The 2026 answer:** pydantic-settings. Type coercion at startup (`"false"` -> `bool(False)`). Missing required values fail immediately. One class, one source of truth, testable with overrides.

**The env var gotcha:** `os.environ.get("WORKERS", 4)` returns `"4"` (string), not `4` (int), even though the default is int. Without pydantic-settings or similar, you parse everything yourself and get it wrong.

**The security gotcha:** Env vars are visible via `/proc/PID/environ` on Linux. For secrets in production, use a secrets manager (Vault, AWS Secrets Manager), not raw environment variables.

---

## Concurrency

### 21. The Real Concurrency Decision Tree

Concrete benchmarks tell the story:

| Scenario | Best choice | Speedup vs sync |
|---|---|---|
| 160 HTTP downloads | asyncio | 29x |
| 160 HTTP downloads | threading | 4.5x |
| CPU-bound (Fibonacci) | multiprocessing | 3.5x |
| CPU-bound | threading | 1.1x **slower** |
| CPU-bound | asyncio | 2.4x **slower** |

**The decision:** I/O-bound + high concurrency -> asyncio. I/O-bound + existing sync code -> `ThreadPoolExecutor`. CPU-bound Python -> multiprocessing. CPU-bound C extensions -> threads (most release the GIL). Unsure -> `concurrent.futures` -- swap executor type without changing calling code.

### 22. The GIL Reality

"Python has the GIL" is taught as "threading is useless." For the dominant web workload (I/O-bound), threading works fine -- the GIL releases during I/O. Five 2-second API calls complete in ~2 seconds with threads.

**Free-threaded Python (3.13+):** Experimental, not production-ready. C extension compatibility is the blocker -- if any dependency re-enables the GIL, you pay single-threaded overhead (1-8%) with no parallelism. The adaptive interpreter is disabled for thread safety. Check py-free-threading.github.io/tracking before committing.

**The 2026 answer:** Threads for I/O-bound. Multiprocessing for CPU-bound Python. Wait on free-threading until the ecosystem catches up.

### 23. The Async Coloring Problem

Introducing one `async def` forces the entire call chain upward to be async. This splits the ecosystem: `requests` vs `aiohttp`, `psycopg2` vs `psycopg3`, `redis-py` sync vs async. Armin Ronacher's 2024 critique: async creates colored functions, colored locks, broken back-pressure, and abandoned coroutines holding resources.

**The real cost in existing codebases:** Django's `sync_to_async` runs sync code in a thread pool, negating asyncio's memory advantage. A single `time.sleep(1)` in an async handler blocks all concurrent requests -- invisible in testing, catastrophic in production.

**When async is worth it:** 10,000+ concurrent I/O-bound connections. Memory advantage (1-2KB per coroutine vs 1MB per thread) only matters at this scale. Websockets, long-polling, fan-out services.

**When it's not:** Typical web APIs <1000 concurrent requests. Sync workers (gunicorn prefork) handle this fine with debuggable stack traces. Existing sync codebases where migration cost is enormous.

**The judgment:** Don't introduce asyncio unless you've measured a concrete concurrency bottleneck. If you need async for one component (websockets), isolate it in a separate service rather than infecting the entire codebase.

### 24. Blocking I/O in Async Is Silent

`async def` does not make code non-blocking -- it merely permits `await`. Sync I/O or CPU work inside `async def` blocks the entire event loop. Your service works in dev, degrades catastrophically under production load.

**The fix hierarchy:** `asyncio.to_thread()` (Python 3.9+) for blocking I/O. `ProcessPoolExecutor` via `loop.run_in_executor()` for CPU work. Async-native libraries (asyncpg, aiohttp, aiofiles) instead of sync equivalents.

**The context variable trap:** `contextvars` (request ID, DB sessions) don't propagate to thread pool workers automatically. Use `contextvars.copy_context().run()` -- without this, you get silent cross-request data leakage. In hybrid frameworks (FastAPI/Starlette), where sync handlers run in a thread pool but middleware is async, context set in the async layer is invisible in the sync layer and vice versa. Logs lose request correlation silently -- you only notice when grepping for a request ID finds half the entries missing.

### 25. multiprocessing Serialization Overhead

Every argument to a `Pool` worker is pickle-serialized, sent over IPC, and deserialized. For large data (NumPy arrays, DataFrames), the serialization overhead can exceed the computation time by 5-6x. Threads avoid this entirely because they share memory.

**Mitigation:** Use threads for NumPy-heavy work (NumPy releases the GIL). Pass file paths instead of objects (Parquet, memmap). Use `multiprocessing.shared_memory` for arrays. Avoid lambdas as task arguments -- they drag hidden state into pickling.

**Critical -- fork + threads = deadlock:** When a process forks, only the calling thread survives in the child. Any lock held by another thread at fork time is permanently locked in the child. The stdlib `logging` module uses internal locks, so forking while any thread is logging creates a deadlock in the child -- the most common victim. The fix: use `"spawn"` or `"forkserver"` start method, never `"fork"` when threads exist (common with NumPy, ThreadPoolExecutor, or background logging).

### 26. concurrent.futures and Task Queues

`concurrent.futures` is the underappreciated sweet spot: same API for threads and processes, swap executor types without changing calling code, built-in future/result collection.

**Upgrade to Celery/ARQ when:** Tasks outlive a request lifecycle, you need retry/scheduling/priority, CPU-bound work in a web server (amortizes worker startup), or you need durable guarantees (broker persistence, dead letter queues).

**Stay in-process when:** Tasks are short-lived and request-scoped, you don't need persistence, and adding a broker (Redis, RabbitMQ) is more infrastructure than the problem warrants.

---

## Performance & Memory

### 27. The Performance Decision Ladder

Before reaching for C, exhaust the Python-native options:

1. **Vectorization** (NumPy/pandas) -- free speedup for numerical work
2. **`functools.lru_cache`/`cache`** -- free for pure functions with repeated inputs
3. **Algorithm change** -- O(n²) -> O(n log n) beats any micro-optimization
4. **PyPy** -- 3-10x for pure Python, zero code changes, C extension compatibility varies
5. **numba JIT** -- competitive with C for numerical loops, zero C code needed
6. **Cython** -- meaningful friction (`.pyx` files, build step) but maintains Python interop
7. **Rust via PyO3/maturin** -- the nuclear option, but it's how the modern Python toolchain works

**Profile first. Always.** You think the bottleneck is in that nested loop. It's actually in the JSON serialization three calls up. `cProfile` in dev, `py-spy` in production (attaches to live PIDs, no restart, negligible overhead).

### 28. When Python Is the Wrong Language

Concrete switch signals:

- **CPU-bound hot loops >1M items/sec:** Rust is ~60x faster, Go ~30x. No Python optimization closes this.
- **Memory-constrained:** Python objects carry 28-56 bytes overhead per object. At 100M objects: Python ~6.4GB, Rust ~800MB.
- **Single binary distribution:** Python needs runtime + venv + deps. Go and Rust compile to one static binary.
- **Sub-millisecond p99 latency:** GIL, GC pauses, interpreter overhead make this extremely difficult.

**The hybrid approach:** Python for orchestration, Rust for hot paths via PyO3/maturin. This is how the entire modern Python toolchain (Pydantic, Ruff, uv) works.

**The staff-level question:** Not "should we rewrite in Rust?" but "which 5% of the codebase is the hot path, and should that 5% be Rust?"

### 29. Profiling: Why You're Optimizing the Wrong Function

You've got a hot loop processing sensor readings. `cProfile` says 60% of time is in `process_reading()`. You're about to reach for Cython. But `py-spy` on the production process shows 60% of time is in `json.dumps()` called from the logging middleware -- invisible to your dev benchmark because it runs with `DEBUG=False`.

**The two-tool approach:** `cProfile` in development (deterministic, focused: `-m cProfile -s cumtime`). `py-spy` in production (sampling profiler, attaches to any PID with no restart, generates flamegraphs, catches behavior that only appears under real load). `line_profiler` for micro-optimization after you've found the actual hot function.

**The signal:** You're reaching for Cython or PyO3 before running `py-spy` on the production process. The bottleneck you measured in dev may not be the bottleneck in prod.

### 30. deepcopy Is 100-1000x Slower Than You Think

`copy.deepcopy()` traverses the entire object graph, maintains a memo dict for shared references, and calls `__deepcopy__` hooks. For a moderately complex object (~1000 nodes), it takes milliseconds per call. In a game tree search, state machine simulation, or request handler that copies config/context, it can consume 25%+ of total CPU.

**Why nobody catches it:** "Copying an object" sounds cheap. It's never flagged by linters. It works correctly. But at 10K calls/second, the overhead dominates your flamegraph. The fix isn't "optimize deepcopy" -- it's "design for immutability so you never need it."

**The alternatives:** Frozen dataclasses (`@dataclass(frozen=True)`). Tuples instead of lists. Explicit "copy-and-modify" constructors (`dataclasses.replace(obj, field=new_value)`). For nested structures, `msgspec.Struct` with `frozen=True` is both immutable and fast to construct.

**The smell:** `copy.deepcopy()` in a hot path. Profile it -- you'll be surprised.

### 31. Generator Exhaustion: The Silent Failure

Iterating an exhausted generator produces zero items with no error -- indistinguishable from "no matching elements."

```python
data = (line.strip() for line in open("log.txt"))
errors = [line for line in data if "ERROR" in line]  # works
warnings = [line for line in data if "WARN" in line]  # always empty, no error
```

**The rule:** Default to `list()` unless you have a concrete reason for laziness: memory pressure (10GB file), infinite sequence, single-pass pipeline. The memory cost of materialization is bounded; the debugging cost of silent exhaustion is not.

**Use type annotations:** `Sequence[float]` (requires len/reuse) vs `Iterable[float]` (single pass). This catches reuse bugs statically -- a function that iterates twice should declare `Sequence`, not `Iterable`.

**The `itertools.tee` trap:** Caches everything the faster iterator consumes. If one runs to completion before the other starts, you've used more memory than `list()` -- in an opaque C structure you can't inspect.

---

## Testing

### 32. Mock Boundaries and Python's mock.patch Target Resolution

The general principle ("don't mock what you don't own") is language-agnostic. The Python-specific trap is `mock.patch` target resolution: you must patch where a name is *looked up*, not where it's *defined*.

```python
# mymodule.py
from os.path import exists
# Test: patch must target 'mymodule.exists', NOT 'os.path.exists'
# because mymodule already imported the reference at import time
```

Getting this wrong is the #1 cause of "my mock isn't working" in Python. The mock is applied correctly -- but to the wrong namespace, so the code under test still calls the real function.

**The depth heuristic:** Mock at the layer immediately inside the boundary. Mocking `S3Client.upload()` tests your calling code. Mocking `boto3.client('s3').put_object()` tests nothing about your abstraction.

**Socket-level interceptors** (`responses`, `respx` for httpx, `aioresponses` for aiohttp) are not true mocks -- they intercept at the transport layer and test your actual serialization. Prefer these over `mock.patch` for HTTP clients.

**The smell:** `@mock.patch("os.path.exists")` in a test for code that does `from os.path import exists`. That mock does nothing to your code.

### 33. Hypothesis: When Property-Based Testing Earns Its Keep

**Worth it:** Roundtrip properties (serialize/deserialize -- property covers entire input space). Mathematical invariants (sorting, arithmetic). Crash fuzzing (Hypothesis shrinking finds minimal reproducers automatically).

**Overkill:** Deterministic functions with obvious outputs (three example tests suffice). Code without clearly stateable properties (you'll underspecify and create false confidence). Integration code hitting external systems (needs fast, deterministic execution).

**The smell:** You're writing Hypothesis tests for CRUD endpoints. Stop. ~5% adoption isn't immaturity -- most application code doesn't have stateable mathematical properties. Hypothesis belongs in utility libraries, parsers, serializers, and algorithmic code.

### 34. pytest at Scale

**Parallelization:** `pytest-xdist -n auto`. 8x for CPU-bound suites, 3x for I/O-bound.

**Fixture design:** Session-scoped fixtures must be parallelism-safe (use `worker_id`). Avoid mutable session-scoped fixtures. Share read-only data at session scope, mutable state per test.

**Marking:** `@pytest.mark.slow`, `@pytest.mark.integration`. CI runs `pytest -m "not slow"` per commit, full suite nightly.

**conftest.py:** Two levels max -- root for infrastructure, test-module for domain. Deep hierarchies create invisible fixture shadowing.

### 35. factory_boy vs Raw Fixtures

**factory_boy dominates in ORM codebases:** One factory per model, lazy FK evaluation, `pytest-factoryboy` bridges factory pattern and pytest DI.

**Raw fixtures win for:** Non-ORM data, infrastructure setup, scenarios where factory magic obscures what the test needs.

**The failure mode:** Over-relying on factory defaults. Tests pass with synthetic data, fail with real data because the factory never produced a null field. Defaults cover the common case; explicit overrides document the contract under test.

### 36. Coverage: What to Target

**Target 80-85% with deliberate exclusions.** The last 10-15% is error handling, defensive code, and platform branches. Going from 90% to 100% produces brittle, low-value tests.

**The better metric:** Mutation coverage (`mutmut`, `cosmic-ray`). 80% coverage killing 90% of mutations is healthier than 95% coverage where tests only assert `status_code == 200`.

**The harmful pattern:** 100% as a CI gate. Teams respond with `assert True`, `# pragma: no cover`, and tests for untestable paths that slow the suite.

---

## Packaging

### 37. uv as the Default

**New projects in 2026: uv.** Single Rust binary replacing pip, pip-tools, pyenv, pipx, and virtualenv. 10-100x faster resolution. Cross-platform lockfiles. Python version management built in.

**Decision tree:** New project -> uv. Conda packages needed (CUDA, GDAL) -> pixi. Existing Poetry that works -> stay. Throwaway script -> pip.

**Why Poetry persists:** Plugin ecosystem, publish workflow, trained teams. uv's project management is newer, less enterprise-battle-tested.

### 38. "requirements.txt Is Not a Lockfile"

`pip freeze` captures versions but: omits hashes (no integrity verification), includes stray packages, doesn't distinguish direct from transitive deps, misses platform-specific packages.

**Use a real lockfile** (uv.lock, poetry.lock, pip-tools). Run `pip audit` or `uv audit` in CI. Deploy with hash verification. PEP 751 aims to standardize across the 5+ incompatible formats.

### 39. Pinning: Libraries vs Applications

**Libraries on PyPI:** Loose bounds. `dependencies = ["requests>=2.28,<3"]`. Over-pinning causes downstream dependency hell.

**Applications deployed to servers:** Pin everything in a lockfile -- exact transitive tree, hashes, platform markers. This is what ships.

**The anti-pattern:** Pinning app deps in `pyproject.toml`. The toml expresses constraints; the lockfile records resolutions. Conflating them breaks upgrade tooling.

### 40. The src/ Layout Question

`src/` layout prevents one concrete thing: accidentally importing dev source instead of the installed package during testing. With flat layout, `import mypackage` in tests can silently import the source tree, masking build bugs.

**When src/ matters:** Complex builds (C extensions, data files), monorepos with multiple packages, anything published to PyPI.

**When flat is fine:** Pure-Python internal tools, apps never published. uv defaults flat; Poetry defaults src/. This disagreement reflects genuine trade-offs, not one being wrong.

---

## Python's Dynamic Nature

### 41. The "Pythonic" Trap

"Pythonic" is optimized for the first write. Staff-level code is optimized for the hundredth read.

**List comprehensions:** One iterable, one filter -- yes. Nested `for` clauses with conditions -- extract to a loop. Side-effecting comprehensions (`[send_email(u) for u in users]`) -- never. Building a list you throw away to execute side effects is unreadable and wasteful.

**"Flat is better than nested":** 3-4 nesting levels are fine if each is a meaningful boundary. A 500-line flat function with scattered early returns is worse than 5 functions of 100 lines. "Flat" means "prefer composition," not "forbid indentation."

**The pattern:** Every "Pythonic" default has a scale threshold past which it becomes wrong. Comprehensions at 3 clauses. EAFP at 20% failure rate. Dynamic typing at 50K lines. The staff engineer knows where those thresholds are.

### 42. Monkeypatching: Three Legitimate Uses

**Legitimate:** Test fixtures (`pytest.monkeypatch` -- scoped, auto-reverted). Documented compatibility shims (patching a third-party bug with a linked issue and removal date). Read-only instrumentation (APM wrappers for tracing).

**Illegitimate:** Multiple patches on the same object (execution order = load order, invisible to review). Patches changing return types (grep lies about what executes). Undocumented "temporary" patches that become permanent debt.

**The rule:** If you need to patch behavior in production, you need a fork or an extension point. Monkeypatching scales inversely with team size.

### 43. The str/bytes Boundary

Python 3's strict split eliminated Python 2's encoding bugs but created boundary bugs:

- **`open("file.txt")`** uses locale encoding: UTF-8 on Linux/macOS, cp1252 on Windows. Code works on the dev's Mac, silently corrupts on Windows servers. Always pass `encoding='utf-8'` until Python 3.15 (which defaults to UTF-8).
- **`response.text`** decodes via charset header (often wrong/missing). Missing charset defaults to ISO-8859-1 per HTTP spec, silently mangling UTF-8. Use `.content` and decode explicitly.
- **f-strings call `str()` on bytes** silently, producing `"b'\\x00\\x01'"` instead of raising.

**The pattern:** Decode at the edges, work with `str` internally, encode at the edges. Type annotations (`def process(data: str) -> str`) catch boundary confusion statically.

---

## Production Gotchas

### 44. Decimal Through JSON Silently Loses Precision

`json.dumps()` can't serialize `Decimal` (raises `TypeError`). The "fix" of `default=float` or a custom encoder silently loses precision. `float(Decimal("0.1234"))` produces `0.12339999999999999580335696691690827719867229461669921875`. Pydantic v2 has this same bug -- JSON parsing goes through `float` before converting to `Decimal`.

**Why it hides:** `0.1234` and the imprecise float *print the same* with default formatting. Tests pass. Months later, penny-rounding errors accumulate in invoicing or settlement calculations. The bug is invisible because you have to look at `repr()`, not `str()`.

**The fix:** Serialize Decimals as strings in JSON. `json.dumps(data, default=str)` is the quick fix. For Pydantic, configure the model: `model_config = ConfigDict(json_encoders={Decimal: str})`. For true performance, msgspec handles Decimal natively.

**The smell:** `default=float` in any `json.dumps()` call. Grep for it -- if you find it in financial code, you have a bug.

### 45. ExceptionGroup and except* (Python 3.11+): The Migration Trap

`asyncio.TaskGroup` wraps concurrent failures in `ExceptionGroup`. You cannot catch individual types with `except ValueError` from a `TaskGroup` -- you must use `except*`. But `except` and `except*` cannot be mixed in the same `try` block. Adopting `TaskGroup` forces `except*` throughout the call chain -- a viral change similar to async coloring.

**The concrete failure:** You migrate from `asyncio.gather()` to `TaskGroup` (the "modern" way), and your existing `except ValueError` handlers silently stop catching errors wrapped in `ExceptionGroup`. Tests pass because they only test single-failure cases. The multi-failure production case surfaces as an unhandled `ExceptionGroup`.

**The judgment:** Don't adopt `TaskGroup` without also migrating exception handlers to `except*`. If your error handling can't easily migrate, `asyncio.gather(return_exceptions=True)` with explicit result inspection is still the safer pattern despite being "old style."

### 46. pytz Is Legacy: The zoneinfo Migration

`pytz` requires `localize()` instead of passing `tzinfo` to the constructor. Passing `tzinfo=pytz.timezone("US/Eastern")` to `datetime()` silently produces the wrong offset -- LMT from 1883, not modern EST/EDT. This is not a theoretical bug; it produces timestamps that are off by minutes.

`zoneinfo` (stdlib since 3.9) works correctly with the constructor. But mixing `zoneinfo` and `dateutil.tz` objects produces different comparison results for semantically identical timestamps -- `ZoneInfo("UTC")` and `dateutil.tz.UTC` are not the same object.

**The migration is not find-replace.** Audit every `pytz.timezone()` -> `ZoneInfo()`. Check for `localize()` calls that become unnecessary. Check for cross-library `datetime` comparisons that silently change behavior.

**The smell:** Any `pytz` import in code targeting Python 3.9+. It's not just deprecated -- it's actively buggy in ways that `zoneinfo` fixes.

### 47. Memory Fragmentation in Long-Running Services

Python's RSS grows monotonically in long-running services even when live object count is stable. This is not a Python memory leak -- it's glibc malloc arena fragmentation. The allocator creates per-thread arenas, and a single long-lived allocation in an arena pins the entire arena from being returned to the OS.

**The debugging trap:** You see RSS growing, add `tracemalloc`, find nothing leaking, blame Python's GC, add `gc.collect()` calls everywhere (which does nothing for this), and eventually add aggressive worker recycling (`--max-requests` in gunicorn) as a band-aid.

**The real fixes:**
- `jemalloc` via `LD_PRELOAD` -- BetterUp documented this fixing their FastAPI RSS creep
- `MALLOC_ARENA_MAX=2` environment variable -- limits arena count
- `ctypes.cdll.LoadLibrary("libc.so.6").malloc_trim(0)` -- periodic manual trim

**The signal:** RSS climbs steadily over hours while `tracemalloc` shows flat Python heap usage. That's malloc fragmentation, not a Python leak. Don't recycle workers until you've tried jemalloc.
