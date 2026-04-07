# Senior TypeScript Engineering Judgment

A decision framework for TypeScript architecture, not a checklist. Each topic is how a staff engineer thinks about the trade-off, written for a mid-level who knows the language but hasn't yet internalized when to break the rules.

---

## Design Philosophy

### 1. The Non-Goals Document Is the Most Important Thing You Haven't Read

TypeScript's official Design Goals wiki page lists what TypeScript will *never* do. Non-goal #3: "Apply a sound or 'provably correct' type system." Non-goal #5: "Add or rely on run-time type information." These aren't limitations -- they're deliberate architectural decisions. Every time you wish TypeScript could do something at runtime (reflection, type guards that actually verify, branded type enforcement), check the non-goals first. If it requires runtime metadata, it's pre-declined.

**The signal:** Before proposing a TypeScript feature or workaround in code review, check the TypeScript FAQ wiki. Features like nominal types (#202, open since 2014), negated types (#4196, open since 2015), and exact/sealed object types (#12936) are acknowledged and deliberately not implemented. These decisions are final.

### 2. Seven Documented Soundness Holes -- Memorize Them

TypeScript is intentionally unsound. Dan Vanderkam catalogued seven sources of unsoundness: (1) `any` silently disables checking, (2) type assertions bypass safety, (3) array/object index access lies about undefined, (4) `@types` declarations can be wrong, (5) mutable arrays are covariant (`Dog[]` assignable to `Animal[]`), (6) function calls don't invalidate narrowing, (7) bivariant method parameters. Each hole exists because fixing it would either require runtime metadata or break too much existing JavaScript.

**The senior move:** Don't try to "fix" these with clever types. Know where they bite and add runtime checks at those specific points. Treating TypeScript as sound (trusting it everywhere) is the false security assumption that produces production bugs.

### 3. Structural Typing Was Mandated by JavaScript, Not Chosen Freely

JavaScript's pervasive use of anonymous object literals, duck-typed callbacks, and ad-hoc objects makes nominal typing nearly impossible to retrofit. Structural typing is the correct model for JavaScript semantics. This isn't a weakness to work around with brands -- it's the design.

**The implication:** When you reach for branded types to simulate nominal typing, you're fighting the type system's fundamental nature. Do it when domain identity genuinely matters (mixing `UserId` with `OrderId` in a payment function). Don't do it as a general "make types stricter" reflex.

### 4. Level-1 Gradual Typing -- Types Are Documentation, Not Contracts

Jeremy Siek (who invented gradual typing) analyzed TypeScript formally and concluded it's "Level 1" -- no-checking semantics where the compiler ignores implicit casts at runtime. Level 2 would check casts at runtime; Level 3 adds blame tracking. TypeScript chose Level 1 because runtime checks would violate the non-goals. The ICSE 2017 study ("To Type or Not to Type", Gao et al.) found TypeScript and Flow each catch ~15% of public bugs. Airbnb's internal data suggests 38% -- higher because it includes bugs caught during development, before public disclosure.

**The calibration:** TypeScript types are compiler hints and documentation, not runtime contracts. They catch real bugs -- but they catch the detectable type-mismatch bugs. Logic errors, specification errors, and architectural mistakes are entirely outside TypeScript's scope.

### 5. The Erasure Principle -- What Gets Deleted

TypeScript erases all type annotations, interfaces, type aliases, `as` casts, and `!` assertions. It does NOT erase enums (which emit runtime objects), namespaces (which emit IIFEs), parameter properties in classes, and decorators with metadata. Node.js 23.6+ type stripping makes this distinction official: erasable syntax works without a compiler; non-erasable syntax requires `--experimental-transform-types`. `const enum` and namespaces are now officially second-class -- they require a compilation step that pure type stripping cannot provide.

**The direction:** TypeScript is moving toward erasable-only syntax. The TC39 Type Annotations proposal (Stage 1) would formalize type syntax in JavaScript itself -- engines would ignore it like comments. `enum` and `namespace` are becoming legacy features.

---

## Type System as Design Tool

### 6. Branded Types -- When the Boilerplate Earns Its Weight

The safety from mixing `UserId` and `ProductId` (both `string`) costs: construction functions, `__brand` noise in IntelliSense, cognitive overhead for new team members, and brand-stripping at every serialization boundary.

**Worth it:** Security-critical IDs (auth tokens, payment references), validated domain strings (email, URL), numeric quantities where confusion is dangerous (`Price` vs `Quantity`). These are the cases where a mix-up is a production incident, not just a test failure.

**Not worth it:** Config keys, internal-only string identifiers, anything where parameter naming and code review already prevent confusion. The boilerplate cost exceeds the safety benefit in a small team where the real risk of passing the wrong ID is low.

**The smell:** Every primitive in the codebase has a brand. That's not type safety -- it's type bureaucracy. Brands should protect against bugs that have actually happened or would be catastrophic if they did.

### 7. Conditional Types -- Library Infrastructure vs Application Vanity

Conditional types (`T extends U ? X : Y`) earn their weight in library infrastructure -- `ReturnType<T>`, `Awaited<T>`, framework type utilities. They become vanity in application code where a simpler union or explicit overload communicates the same thing. The same feature is essential in `@types/react` and a maintainability hazard in a 3-person app's form handling.

**The test:** Will this conditional type be consumed by people who didn't write it? If yes, the complexity is justified -- it provides type safety to callers who shouldn't need to understand the implementation. If the only consumer is the author, a union or overload is almost always clearer.

### 8. Mapped Types -- When Transformation Justifies the Machinery

Mapped types `{ [K in keyof T]: ... }` pay off for generating consistent sets: all-optional versions, all-readonly versions, event maps from action enums. They become overengineering when used to produce a single concrete type that could just be written directly. A 10-line mapped type that produces `PartialUser` is worse than just writing `PartialUser` with optional fields -- unless you maintain 20 such variants that must stay in sync.

**Homomorphic vs non-homomorphic:** `{ [K in keyof T]: ... }` is homomorphic (preserves `readonly`/`?` modifiers, distributes over arrays). `Record<K, V>` is non-homomorphic (creates new properties, copies nothing). When you want modifiers preserved from the input type, you must use the homomorphic form. This distinction is invisible until your mapped type silently drops `readonly` on every property.

### 9. Template Literal Types -- Compile-Time String Validation vs IDE Tax

Real production uses: typed CSS class prefixes, type-safe i18n key paths (`"users.name"` resolves to nested object), event handler generation (`on${Capitalize<EventName>}`). The footgun: combining large union cross-products creates combinatorial explosion. Three unions of 20 members each = 8,000 generated types. i18next key safety is worth the IDE cost; constructing every possible Tailwind class combination in the type system is not.

**The ceiling:** Keep template literal unions under ~100 members. Beyond that, the compile-time cost outweighs the benefit. If your type generates thousands of string variants, you've moved from "type safety" to "type system abuse."

### 10. Discriminated Unions as State Machines

`{ status: 'loading' } | { status: 'error', error: Error } | { status: 'success', data: T }` eliminates impossible states that `isLoading: boolean, isError: boolean` permits. With booleans, `isLoading: true, isError: true` is representable. With discriminated unions, it's not.

**The spectrum:** Discriminated unions for 2-5 state models (UI loading states, form steps, connection status). XState for complex machines with >5 states, async transitions, and visualization needs. Raw booleans for genuinely independent binary flags that aren't state machines (feature flags, toggles).

### 11. `infer` -- Library Infrastructure, Not Application Code

`infer` in conditional types powers `ReturnType<T>`, `Parameters<T>`, `Awaited<T>`. In library code, it's the correct tool for extracting type information from generic inputs. In application code, a developer reaching for `infer` usually needs to step back. If you're writing `type ExtractPayload<T> = T extends Action<infer P> ? P : never` in a business module, ask: could you just name the type directly?

**The signal:** `infer` appearing in application code is a strong smell of overengineering unless you're building a framework or shared type utility.

### 12. Type-Level Programming -- Turing Completeness as a Warning Sign

TypeScript's type system is Turing complete (confirmed in GitHub issue #14833). People have built compile-time parsers, validators, chess engines, even DOOM in the type system. The practical judgment: if your type requires documentation to understand, it has failed its purpose. Types ARE documentation. A type that itself needs explaining is a net negative.

**The smell:** A `.d.ts` file or utility type that nobody on the team can modify without the original author explaining it. Type-level code has no debugger, no stack traces, and error messages that reference internal type expansion. The maintenance cost compounds invisibly.

### 13. Generic Constraints -- Tight Enough to Self-Document, Loose Enough to Compose

`<T extends string>` is tighter than `<T>` but looser than `<T extends UserId>`. Library API design judgment: constraints should express the actual requirements of the function, not the specific type the author had in mind. Over-tight constraints break legitimate use cases that the author didn't anticipate; under-tight constraints allow nonsensical type arguments that produce confusing errors deep inside the implementation.

**The test:** Can a caller use your generic with a type you didn't envision, and would that be correct behavior? If yes, your constraint is the right tightness. If callers keep hitting "Type X does not satisfy constraint Y" with types that should work, your constraint is too tight.

### 14. Variance Annotations (`in`/`out`) -- Performance and Correctness

TypeScript 4.7 added explicit variance annotations: `out T` for covariant (output only), `in T` for contravariant (input only), `in out T` for invariant. Without annotations, TypeScript must analyze every use of T to infer variance -- expensive for complex generic interfaces. With annotations, this analysis is skipped.

**When to use:** Library authors with complex generic interfaces, especially recursive types or deep hierarchies. The performance benefit is real and TypeScript validates the annotation against actual usage.

**The subtlety nobody mentions:** `strictFunctionTypes` makes function expressions contravariant in parameters but leaves method signatures bivariant. `interface Foo { handler(x: Dog): void }` allows assigning `(x: Animal) => void` to handler. Change to `handler: (x: Dog) => void` (property syntax) to get contravariant checking. Same logic, different safety, based on syntax.

---

## How Typed Should This Be?

### 15. `strict: true` Is a Floor, Not a Ceiling

`strict: true` enables eight flags. Most teams treat enabling it as the end goal. The flags that matter beyond strict: `noUncheckedIndexedAccess` (array access is unsafe without it), `exactOptionalPropertyTypes` (distinguishes "property missing" from "property is undefined"), `noPropertyAccessFromIndexSignature` (forces bracket notation for dynamic keys). None of these are in `strict: true`.

**The judgment:** Which of these non-strict flags to enable is a genuine team decision about false-positive tolerance. `noUncheckedIndexedAccess` produces noise in `for` loops where the index is provably valid. `exactOptionalPropertyTypes` breaks most codebases on first enable. Choose based on your codebase's actual pain points, not a blog post's recommendation.

### 16. `strictNullChecks` and `noImplicitAny` Interact Non-Monotonically

During migration, enabling these flags in the wrong order creates unexpected temporary type errors. Enabling `noImplicitAny` first is recommended because it forces explicit annotations that then make `strictNullChecks` errors more localized. Enabling `strictNullChecks` first on code full of implicit `any` creates cascading errors where null flows through untyped code paths in confusing ways.

**The signal:** You're planning a strict-mode migration and treating flag order as irrelevant. It's not -- the interaction is documented but not in official guidance.

### 17. `any` -- The Three Legitimate Cases

`any` opts out of the type system entirely and is contagious -- it spreads through assignments without any visible trace. `unknown` forces narrowing before use. The judgment: `any` is acceptable in exactly three cases: (1) migration escape hatches with `// TODO: type this` comments and a tracking mechanism, (2) untyped third-party code with no `@types` package where writing a full declaration isn't worth the effort, (3) immediately before runtime validation (`const raw: any = JSON.parse(text); const user = UserSchema.parse(raw)`). Every other `any` is a deferred bug.

### 18. `any` Contagion -- The Invisible Spread

Once a single node in the dependency graph returns `any`, everything downstream becomes `any` -- silently, without the word `any` appearing in your source code. The primary vector: `.d.ts` declaration files for third-party libraries. If a library types a return value as `any`, every variable derived from it is effectively untyped. Dan Vanderkam documents that well-maintained TypeScript projects frequently have 30-40% of values effectively `any` without a single developer having written the word.

**The defense:** The `type-coverage` CLI tool measures what percentage of identifiers are not `any`. Run it. The number is usually lower than you think. `@typescript-eslint/no-unsafe-assignment` (requires `recommended-type-checked` with type information) catches `any` propagation -- but most projects use `recommended` without type info and miss this entire class.

### 19. Type Assertions -- The Narrowing vs Broadening Distinction

`as const` is always safe -- it restricts, not expands. `as SomeType` that narrows (DOM queries like `as HTMLInputElement`, JSON boundaries after validation) is acceptable with a `// SAFETY: ...` comment explaining why the assertion holds. `as SomeType` that broadens a type (making the compiler accept something it correctly rejected) is dangerous and usually wrong.

**The convention:** The `// SAFETY:` comment convention (used at LinkedIn and other large codebases) forces the author to articulate why the assertion is correct. If you can't write a convincing safety comment, the assertion probably isn't safe.

### 20. Runtime Validation -- Where the Trust Boundary Actually Is

TypeScript erases at compile time. At every trust boundary -- HTTP responses, database results, `JSON.parse`, `process.env`, WebSocket messages, `localStorage`, URL parameters -- the type system makes claims the runtime cannot enforce. The senior pattern: pick a validation library (Zod, Valibot, ArkType) and apply it consistently at these boundaries.

**The judgment call:** Where exactly the trust boundary is. Data from your own database through your own ORM with generated types? Probably trusted. Data from an external API you don't control? Never trusted. The same HTTP response is trusted or untrusted depending on who controls the server. Map your boundaries explicitly; don't sprinkle Zod randomly.

### 21. User-Defined Type Guards Are Unverified

`function isUser(x: unknown): x is User { return typeof x === 'string'; }` typechecks -- the function lies. TypeScript does not verify that the predicate body actually corresponds to the claimed type. This is a known issue (#29980) labeled "Too Complex" to fix. Incorrect type guards produce runtime bugs that look like impossible type errors.

**The fix:** For trust boundaries, use runtime validation (Zod) instead of hand-written type guards. For internal code where the guard is simple and obvious, type guards are fine. The danger zone is complex guards with multiple conditions -- any mistake in the logic silently corrupts the type.

**TS 5.5 improvement:** Inferred type predicates now automatically narrow `array.filter(x => x !== undefined)` to remove `undefined`. This eliminates the most common case where hand-written type guards were needed.

### 22. The Three-Way Literal Typing Choice

The existing checklist covers `as` vs `satisfies`. The judgment call is the three-way choice for object literals: annotation (`: MyType` -- widened, loses literals), `as const` (narrow literals, no schema validation), `satisfies` (validates AND preserves inference). The correct default for config objects is `satisfies`.

**The combination nobody uses:** `const x = { ... } as const satisfies MyType` gives immutability AND validation AND literal types -- the tightest possible typing for a constant. This is the correct pattern for route tables, event maps, and any constant object that should be both type-checked and deeply readonly.

### 23. When TypeScript Migration Isn't the Right Fix

A documented case: a team rewrote 50,000 lines to TypeScript. The result: 38% `any` annotations, slower sprints, and false confidence from types that claimed a payment field was always present when it wasn't at runtime. Their actual problems were testing discipline, rushed code reviews, and communication -- not type safety. TypeScript doesn't fix specification errors, which account for most bugs.

**The smell:** The team's bug tracker is full of "we built the wrong thing" and "requirements changed," and someone proposes TypeScript migration as the fix. TypeScript catches type errors. It doesn't catch logic errors, missing requirements, or architectural mistakes.

---

## Architecture & Module System

### 24. Monorepo Type Sharing -- Five Strategies, No Clear Winner

Colin McDonnell (Zod author) documented five strategies: project references, `publishConfig`, `tsconfig.paths`, `tshy` liveDev, and custom export conditions. Each has footguns. `paths` is disliked by the TypeScript team (it's a compile-time alias, not a module resolution override). `publishConfig` is pnpm-only. Custom export conditions (defining a `"@myorg/source"` condition) is the current cleanest approach but requires build tool support.

**The judgment:** There is no correct universal answer. Pick the strategy that matches your monorepo tooling (Nx, Turborepo, pnpm workspaces) and accept its tradeoffs. The worst outcome is mixing strategies within one monorepo.

### 25. Project References -- When the Maintenance Cost Exceeds the Performance Gain

TypeScript project references enable incremental compilation and better IDE performance. Shopify saw 10x improvements (155s to 8s startup) on a massive codebase. Turborepo recommends against them for smaller codebases, favoring the "internal package" pattern (pointing `main`/`types` directly at `.ts` source files, letting the consuming project's tsc handle them).

**The decision boundary:** If your IDE is noticeably slow on your monorepo, project references are worth the configuration overhead. If it's not, internal packages are simpler. Target 5-20 evenly-sized projects mirroring your dependency graph. The performance wiki says `--incremental` alone (without project references) gives significant savings for single-package codebases.

### 26. CJS/ESM Dual Publishing -- Still a Mess

Supporting both `require()` and `import` requires correct `exports` field, correct `.d.ts`/`.d.cts` routing, correct file extensions, and tooling support. TypeScript cannot emit `.cjs`/`.mjs` from a single source without build tools (`tsup`, `tsdown`). The dual package hazard (two instances loaded simultaneously) is a real bug class -- `instanceof` fails, singletons duplicate.

**The spectrum:** Sindre Sorhus went ESM-only (broke thousands of CJS consumers). Node v22+ supports `require(esm)` natively, reducing the pressure. New libraries: go ESM-only unless your audience is provably CJS-locked. Existing libraries: maintain dual publishing with `tsup` if consumers need both, but plan an ESM-only future.

### 27. `moduleResolution` -- The Setting That Breaks Everything

`"node"` (legacy): doesn't understand `package.json` `"exports"`. Broken for modern packages -- never use it for new projects. `"node16"`/`"nodenext"`: mirrors Node.js's actual ESM algorithm, requires `.js` extensions in relative imports. `"bundler"`: supports `"exports"` without requiring file extensions, designed for Vite/webpack/esbuild-processed code.

**The rule:** `"bundler"` for projects that go through a bundler. `"nodenext"` for Node.js ESM projects without a bundler (CLIs, servers, scripts). Never `"node"`. `"nodenext"` is forward-looking -- identical to `"node16"` today but will track new Node.js ESM features.

### 28. `verbatimModuleSyntax` -- The Future of Import Hygiene

TypeScript 5.0 replaced `isolatedModules` + `importsNotUsedAsValues` with one flag. It enforces that imports are written exactly as they'll appear in output -- if it's type-only, you must write `import type`. This makes bundler behavior predictable and prevents implicit import elision from breaking side-effect imports.

**Enable it:** For all new projects targeting modern bundlers. The cost is slightly more verbose imports. The benefit is that your code means what it says -- no TypeScript-specific import magic that breaks when you switch transpilers.

### 29. `isolatedModules` -- The Tax for Fast Transpilers

When using esbuild, SWC, or Babel instead of `tsc`, set `isolatedModules: true`. This prevents features that require cross-file knowledge: ambient `const enum` from external modules, type re-exports without `export type`. The rule: if your project uses any transpiler other than `tsc`, `isolatedModules: true` is mandatory. Without it, transpilation can silently produce incorrect JavaScript.

**The modern combo:** `isolatedModules: true` + `verbatimModuleSyntax: true` for any project using fast transpilers. Together they ensure each file is self-contained and import semantics are explicit.

### 30. `isolatedDeclarations` -- The Unlock for Parallel Builds

TS 5.5 introduced `isolatedDeclarations`: require explicit return types on exports so `.d.ts` generation becomes pure syntax stripping -- no cross-file inference needed. This enables parallel declaration emit and is how JSR (Deno's package registry) ships TypeScript source directly. The tradeoff: developers must annotate exported function return types explicitly, losing some ergonomic inference.

**When to enable:** Library code that ships `.d.ts` files, especially in monorepos where declaration emit is a bottleneck. Application code that never generates declarations doesn't need it.

### 31. Declaration Files -- Generate, Don't Write

Hand-writing `.d.ts` files is almost always wrong for TypeScript source. `declaration: true` in tsconfig generates correct `.d.ts` from your source. Manual `.d.ts` files go stale the moment someone edits the implementation and forgets to update the declaration.

**The only valid cases:** (1) Wrapping untyped JavaScript with no `@types` package available. (2) Writing global ambient declarations (`declare global`) that have no implementation counterpart. (3) Contributing to DefinitelyTyped for a library you don't own. Everything else: generate.

### 32. DefinitelyTyped vs Bundled Types -- The Synchronization Problem

If your package is written in TypeScript, bundle your generated `.d.ts` files -- don't use DefinitelyTyped. `@types/` packages can drift from library versions (`@types/react` frequently lags React releases), and version mismatches between a library and its types are silent until type errors appear in consumers.

**The `dependencies` vs `devDependencies` trap:** If your library exports types that reference `@types/node` types (e.g., a function returns `Buffer`), `@types/node` must be in `dependencies`, not `devDependencies`. If you only use Node types internally, `devDependencies` is correct. Getting this wrong causes type errors in consumers that are impossible to debug without reading your package.json.

### 33. `skipLibCheck` -- Development Speed vs Hidden Type Conflicts

`skipLibCheck: true` skips type checking declaration files, cutting compile time significantly. The hidden cost: type conflicts between libraries (two packages declaring conflicting globals) are silently swallowed, surfacing only at runtime. Safe in projects with well-maintained dependencies; risky with many `@types/` packages.

**The tradeoff:** Enable it in CI for faster builds, but run a periodic full check (without `skipLibCheck`) to catch declaration conflicts. Or accept the slower build and catch conflicts immediately. There's no free lunch here.

### 34. `import type` Enforcement -- Correctness Over Convenience

`import type { User } from './user'` ensures the import is elided at runtime -- no side effects, no circular dependency at runtime. Enforcing it via `@typescript-eslint/consistent-type-imports` prevents a class of bugs where a type import accidentally creates a runtime dependency cycle. The cost is slightly more verbose imports and a lint rule to configure. The benefit compounds in large codebases where circular imports are otherwise invisible until production crashes.

---

## Runtime vs Type-Level

### 35. Enums -- The Full Picture Beyond Bidirectional Mapping

String enums emit runtime objects (debuggable, but not tree-shakeable). `const enum` inlines values at compile time -- but breaks with `isolatedModules`, breaks across package boundaries (version A inlined at compile time, version B loaded at runtime = silent wrong values), and is banned by Google and Azure SDK style guides.

**The modern recommendation:** `as const` objects for most cases (`const Status = { Active: 'active', Inactive: 'inactive' } as const`). String union types for simple enumerations (`type Status = 'active' | 'inactive'`). Actual `enum` only when you need runtime reflection (iterating over values) and can accept the tree-shaking cost. `const enum` essentially never -- the cross-package version hazard is production-dangerous, which is why both the Google TypeScript Style Guide and Azure SDK guidelines ban it. Node.js type stripping doesn't support `enum` at all without `--experimental-transform-types`, further pushing enums toward legacy status.

### 36. Decorators -- Experimental vs TC39 Stage 3 Are Incompatible

TypeScript's experimental decorators (the ones NestJS, TypeORM, and Angular use) and TC39 Stage 3 decorators are semantically different. Parameter decorators exist in experimental but are intentionally absent from Stage 3. Migrating from experimental to Stage 3 decorators is a breaking change that requires touching all decorator-based code. NestJS still requires `experimentalDecorators: true`.

**The judgment:** If you're starting a new project with no decorator dependencies, use TC39 Stage 3 decorators (no flag needed since TS 5.0). If you depend on NestJS or other experimental-decorator frameworks, you're locked to the old system until those frameworks migrate. Don't mix both in one codebase.

### 37. Type Narrowing After Async -- A Known Unsoundness

TypeScript's narrowing doesn't persist across `await` for mutable variables. After `if (x !== null) { await something(); use(x); }`, `x` is back to possibly-null because the awaited code could have mutated it. The workaround: assign to a `const` before the await (`const definitelyX = x; await something(); use(definitelyX)`), or re-narrow after.

**The deeper issue:** This isn't a bug -- it's correct. An async operation yields control, and anything mutable could change. The compiler can't prove it didn't. The mistake is treating `let` variables as stable across yield points. Use `const` for anything that matters.

### 38. Type Widening -- `let` Widens, `const` Doesn't, Objects Always Widen

`const x = "foo"` infers `"foo"` (literal type). `let x = "foo"` infers `string`. But `const obj = { x: "foo" }` -- `obj.x` is `string`, not `"foo"`, because object properties are mutable. `as const` is required for deep literal inference on objects. This creates a class of bugs where developers expect object property types to be literal when they're widened.

**The pattern that bites:** Passing an object to a function that expects a literal union. `const options = { method: "GET" }; fetch(url, options)` -- TypeScript may complain because `options.method` is `string`, not `"GET"`. The fix is `as const` on the object or `as const` on the specific property.

### 39. Declaration Merging as a Bug Source

Interfaces with the same name in the same scope silently merge. This means an ambient declaration from a library can retroactively add properties to your interfaces without any error. A concrete bug class: `lib.dom.d.ts` or a `@types/` package declares an interface with the same name as yours, and the properties merge silently. Your `Request` interface suddenly has properties you didn't define.

**The defense:** Use `type` aliases instead of `interface` when you don't want consumers or ambient declarations to extend your type. `type` aliases cannot be merged. For library authors who deliberately want declaration merging (so consumers can extend), use `interface` -- but document which interfaces are extension points. Unexpected merges from name collisions are a real, TypeScript-specific class of silent bugs that no amount of `strict` flags will catch.

### 40. `infer` in Covariant vs Contravariant Position

When `infer T` appears in a covariant position (function return type), multiple candidates produce a union. In a contravariant position (function parameter), they produce an intersection. This is not clearly documented and produces surprising results when writing utility types over function signatures.

**The concrete case:** You write a utility type to extract the combined parameters of several function overloads. You expect a union of parameter types; you get an intersection. Staff engineers know this and use it deliberately (intersection in parameter position is how `UnionToIntersection<T>` works). Mid-level engineers are surprised when their `infer`-based utility type produces an intersection they didn't intend. If you see an unexpected intersection from `infer`, check whether the inferred position is contravariant.

### 41. Optional Parameter vs `| undefined` -- Different Assignability

`(x?: string) => void` and `(x: string | undefined) => void` look equivalent but have different semantics. The first means the parameter can be omitted entirely (`fn()`); the second means it must be passed, even as `undefined` (`fn(undefined)`). With `exactOptionalPropertyTypes`, the distinction is enforced for object properties too: `{ x?: string }` means `x` can be absent, while `{ x: string | undefined }` means `x` must be present with value `string | undefined`.

**The bug:** Mixing these in callback types. If your API accepts `(handler: (x?: string) => void)` and a caller passes a function that requires `x` to be passed, TypeScript may allow the assignment but the behavior differs at runtime -- the handler is called without the argument it expects. This is especially subtle in event-handler-style APIs.

### 42. Excess Property Checking -- The Inline vs Variable Inconsistency

`const x: MyType = { a: 1, extra: 2 }` -- TypeScript error. `const temp = { a: 1, extra: 2 }; const x: MyType = temp` -- no error. Object literals get special "excess property checking" (likely typos). Variable assignment doesn't (legitimate structural compatibility). This is intentional and documented but surprises engineers who expect structural typing to be consistent everywhere.

**The implication:** If you want to catch extra properties on data from external sources, you can't rely on TypeScript -- it only catches them on fresh literals. At trust boundaries, use runtime validation that rejects unknown properties (Zod's `.strict()`).

### 43. Method Bivariance vs Function Contravariance

With `strictFunctionTypes: true`, function expressions are checked contravariantly in parameters (safe). But methods defined using method syntax (`method(x: T): void`) remain bivariant (unsafe). This means the same callback typed as a method vs a function property has different safety guarantees.

**The practical implication:** `interface Events { handler(e: MouseEvent): void }` allows assigning `(e: Event) => void` -- unsound because the handler expects MouseEvent properties that Event doesn't have. Change to `handler: (e: MouseEvent) => void` to get contravariant checking. Libraries with event-like interfaces should prefer property syntax for safety.

---

## Error Handling

### 44. No Typed `catch` -- The Fundamental Limitation

`catch (e)` gives `e: unknown` (with `useUnknownInCatchVariables`) or `e: any`. You cannot write `catch (e: SpecificError)`. TypeScript rejects it because JavaScript allows throwing anything -- strings, numbers, `undefined`. This means error types are not part of function signatures, callers can't know what a function throws, and the type system provides zero help for error propagation.

**The consequence:** Error handling in TypeScript is inherently a runtime discipline. No amount of typing fixes the fact that `throw` is untyped. This is why Result types exist as an alternative.

### 45. Result/Either Pattern -- Right Scope, Wrong Scope

`Result<T, E> = { ok: true, value: T } | { ok: false, error: E }` forces explicit error handling at call sites. It works well for business logic errors with 2-4 known variants (validation, not-found, authorization denied). It fights JavaScript idioms when applied universally: most library APIs throw, `async/await` integrates with `try/catch` not `.map`/`.flatMap`, and wrapping every trivial function in Result turns simple code into monadic ceremony that the team must understand to read.

**The spectrum:** Thrown exceptions for unexpected errors (bugs, infrastructure failures the caller can't meaningfully handle). Result types for expected business failures the caller MUST handle differently. Effect-TS or neverthrow for complex dependency chains where monadic composition pays off. The overengineering pattern: applying Result to every function including trivial ones, forcing callers to chain `.map`/`.flatMap`/`.match` where a simple `try/catch` would be clearer. The pattern scales when the team has buy-in on functional style and when failure modes are genuinely diverse.

### 46. `never` for Exhaustiveness -- Build-Time vs Runtime Guarantee

Using `never` in switch default catches missed cases at build time. The `assertNever(x: never): never` pattern throws at runtime if reached. The subtlety: `never` exhaustiveness is only as good as your discriminant. If the discriminant comes from user input or an external API, values outside your union can reach the default at runtime even though TypeScript says they can't.

**The judgment:** Use strict `assertNever` (throws) for state machines where reaching default means a bug in YOUR code. Use weak exhaustiveness (log and return a safe default) where the discriminant crosses a trust boundary and could contain values your type doesn't model.

### 47. Error-Discriminated Return Types vs Thrown Errors

Instead of `throw new NotFoundError()`, return `{ type: 'not-found' } | { type: 'success', data: T }`. The caller gets exhaustive checking on error types. The downside: every intermediate function must propagate the union, widening return types up the call chain. Thrown errors jump the call stack automatically.

**The trade-off:** Discriminated return types make error handling visible and type-safe at the cost of verbose signatures. Thrown errors are invisible to the type system but work naturally with `try/catch` and `async/await`. For library boundaries where callers must handle specific errors, discriminated returns are better. For application code where errors propagate to a top-level handler, throwing is simpler.

---

## Testing

### 48. Type Testing -- When Library Code Needs `expect-type`

Application code almost never needs type tests. Library code -- especially published packages where the type API is the contract -- benefits from `expect-type`, `tsd`, or `vitest --typecheck` to prevent accidental type regressions. If users write code against your types, type tests are CI-worthy. If you're building an internal app, they're probably not.

**The tools:** `expect-type` (used by Apollo Client, Prisma, tRPC). `tsd` (used by Puppeteer, Socket.IO, Bun, Vue). Vitest now ships built-in type testing APIs, lowering adoption friction. The choice between them matters less than having any type tests at all for your public API surface.

### 49. Mocking in TypeScript -- DI vs Module Mocking vs `as unknown as T`

Three approaches: (1) Dependency injection -- everything is type-safe, adds construction boilerplate. (2) `jest.mock()` -- module-level mocking, requires `as unknown as MockType` to satisfy TypeScript, breaks type safety in tests. (3) `vi.spyOn()` / `jest.spyOn()` -- type-safe for method mocking on existing objects.

**The smell:** `as unknown as T` appearing frequently in test files. It usually indicates the code under test is tightly coupled to concrete implementations rather than accepting injected dependencies. The fix isn't more creative casting -- it's restructuring the production code to accept its dependencies as parameters.

### 50. Testing Type-Level Code -- Assignability vs Exact Equality

`expectTypeOf<ReturnType<typeof myFn>>().toEqualTypeOf<User>()` looks solid, but variance subtleties mean the test can pass when the actual type is wider than expected. `toEqualTypeOf` checks mutual assignability, which isn't the same as structural equality for complex types with optional properties or unions.

**The judgment:** For simple types, `toEqualTypeOf` is fine. For complex types with optionality, unions, or generics, supplement with `toMatchTypeOf` (one-directional) and explicit negative tests (`expectTypeOf<X>().not.toEqualTypeOf<Y>()`). The false confidence from passing type tests that don't catch the actual regression is worse than no type tests at all.

---

## Performance & DX

### 51. Compile Time Budget -- O(n^2) Unions and Recursion Limits

Large unions and intersections are O(n^2) in the TypeScript checker -- eliminating redundant members requires pairwise comparison. A 2,000-member union with a generic constraint = 4,000,000 checks per use. Recursive conditional types hit hard limits: 1,000 for tail-recursive patterns (since TS 4.5), 45 for non-tail-recursive. Template literal types with union interpolation create combinatorial explosion: three unions of 20 members = 8,000 generated types.

**The practical ceiling:** Keep unions under ~100 members. The common offenders: route type unions from file-based routers, i18n key unions, and event name unions. For large domains, use a branded type with runtime validation instead of a 1,000-member string union. Keep recursive types tail-recursive. Profile with `tsc --generateTrace` and `@typescript/analyze-trace` when compile times surprise you.

### 52. `interface` vs `type` Alias -- The Performance-Sensitive Choice

Interfaces with `extends` are cached by the TypeScript checker; type aliases with `&` intersections are re-evaluated each time. For hot paths in type checking (large objects extended frequently), `interface extends` is meaningfully faster than `type &`.

**The rule:** Use `interface` for object shapes that will be extended or implemented. Use `type` for unions, mapped types, utility combinations, and anything that isn't an object shape. The performance difference is invisible at small scale but measurable in large codebases with deeply nested type hierarchies.

### 53. Type Instantiation Depth -- When to Fight vs Redesign

Error TS2589 ("Type instantiation is excessively deep and possibly infinite") means TypeScript hit its recursion limit. Workarounds exist: tail recursion with accumulator types, intersection type counter resets, deferred instantiation via object properties. Each extends the limit but adds complexity.

**The deeper judgment:** If you're hitting the recursion limit, the type is probably doing too much work. The question isn't "how do I raise the limit?" but "should this computation happen at the type level at all?" A runtime check with `assert` or a simpler type with a comment is usually better than a 50-line recursive conditional type that only the author can maintain.

### 54. `tsc` vs `swc` vs `esbuild` -- The Architectural Split

`tsc`: type-checks AND transpiles. The only tool that produces accurate `.d.ts` files. 3-9x slower than alternatives for transpilation. `swc`/`esbuild`: type-strip only, 4-25x faster. They produce no type information and cannot generate `.d.ts` files.

**The correct modern split:** `swc` or `esbuild` for dev server and build transpilation (speed). `tsc --noEmit` for CI type checking (correctness). `tsc --declaration --emitDeclarationOnly` for `.d.ts` generation (library publishing). Adding `tsc --noEmit` to CI is not redundant with using esbuild in your build -- esbuild silently ignores type errors.

### 55. TypeScript 7 (Go Port) -- 10x Faster, Same Semantics

The Go port delivers 10x speedup from compiled native code, not architectural changes. VS Code codebase (1.5M LOC): 77.8s to 7.5s (10.4x). Memory: roughly half. Why Go not Rust: direct port of the JS codebase (not a rewrite), esbuild validated the approach.

**What doesn't change:** Type system semantics are identical. No new type features, no changed unsoundness. The same algorithmic O(n^2) union complexity applies, just 10x faster. Don't wait for TypeScript 7 to bail you out of complex-type performance problems -- reduce the complexity now. The Go port ships the same algorithms at compiled speed, not better algorithms.

### 56. Profiling -- Finding What Makes Your Types Slow

`tsc --extendedDiagnostics`: per-phase timing in milliseconds. `tsc --generateTrace tracing_output/`: JSON trace viewable in Chrome DevTools Performance tab -- shows which types are most expensive. `@typescript/analyze-trace`: CLI tool that identifies the slowest type operations. For IDE slowness: `"typescript.tsserver.log": "verbose"` in VS Code settings.

**The smell:** You're guessing which types are slow based on intuition. Profile first. The actual bottleneck is often a single utility type or a union intersection from a duplicate dependency -- not the feature you're blaming. Outschool documented a case where duplicate `@mui/material` versions caused an 844^2 = ~712,000 pairwise comparison in a union intersection, doubling compile time overnight. A `pnpm overrides` fix reduced one file from 168s to 30s.

### 57. The `OmitNeverKeys` Anti-Pattern -- Eager Evaluation Trap

Wrapping large object types in utility types that filter `never`-valued properties (like `OmitNeverKeys<T>`) forces TypeScript to eagerly evaluate the entire object type upfront, defeating lazy property resolution. During tRPC v10 development, removing a single `OmitNeverKeys` wrapper yielded a 2.4x per-file speedup (332ms to 136ms) -- the eager evaluation was the dominant cost.

**The fix:** Store subsets in separate named fields rather than filtering at the type level. The general principle: utility types that iterate over all properties of a large object type are expensive. Named sub-types that extract what you need are cheap. Avoid type-level filtering when you can restructure the data model.

---

## Ecosystem & Frameworks

### 58. JSDoc for Libraries -- The Rich Harris / Svelte Approach

Rich Harris migrated Svelte's internals from TypeScript to JavaScript + JSDoc annotations in 2023. The reasoning: TypeScript's build step creates friction for library development (can't modify and immediately run without rebuilding). `tsc --declaration --emitDeclarationOnly` still generates `.d.ts` files for consumers. His framing: "types with a build step for apps, types without a build step for libraries."

**The judgment:** JSDoc + `checkJs` is a legitimate alternative for library source code where eliminating the compile step reduces friction and CI complexity. It's not a rejection of types -- it's a rejection of the build step. For application code where you're already running a build, TypeScript source is the better default.

### 59. Frontend vs Backend TypeScript -- Different Correctness Priorities

On the frontend: exhaustive UI state modeling (discriminated unions for loading/error/success) earns its weight because impossible states cause visible UI bugs. On the backend: runtime validation at every API boundary is non-negotiable because data crosses trust boundaries constantly. The type concerns differ: frontend prioritizes "impossible state" prevention; backend prioritizes trust-boundary validation and database type mapping.

**The mistake:** A single shared type strategy for both frontend and backend. Frontend types can be looser on runtime validation (the data came from your own API). Backend types must be paranoid about external input. Sharing the User type between frontend and backend is fine; sharing the validation strategy is not.

### 60. Library vs Application Code -- Generics Are Harder to Justify in Apps

Library authors write generic, composable types because consumers compose them in unknown ways. Application code's types can be much more concrete -- `getUserById(id: UserId): Promise<User>` doesn't need generics. The trap: application developers learn advanced TypeScript from library code (Matt Pocock, TanStack source, tRPC internals) and bring those patterns into app code where they add complexity without composability benefits.

**The signal:** A generic parameter that's always instantiated with the same type in practice. `function processOrder<T extends Order>(order: T)` where T is always `Order` -- just write `function processOrder(order: Order)`.

### 61. Framework Type Tax -- What Frameworks Force on You

NestJS requires `experimentalDecorators: true` + `emitDecoratorMetadata: true` + `reflect-metadata` runtime dependency. Angular's decorator-based DI has the same requirements. React's `@types/react` has complex generic signatures that produce unreadable error messages when wrong. These aren't optional -- they're the framework's type tax.

**The judgment before adopting a framework:** What TypeScript features does it lock you into? What type complexity does it add to every file? If the framework requires experimental features (decorators, metadata reflection), you're coupling your TypeScript configuration to the framework's choices. This isn't necessarily a dealbreaker, but it should be a conscious decision, not a surprise discovered six months in.

### 62. tRPC / End-to-End Inference -- HKT Limitations at Scale

tRPC achieves end-to-end type safety without code generation by using TypeScript's inference directly. The fundamental limitation: TypeScript lacks Higher Kinded Types (HKT). Large tRPC routers degrade IDE performance as the inferred router type grows. tRPC documented cases where a simple router with a Prisma context produces 3,500-line type declarations, of which 3,300 lines are Prisma types repeated six times.

**The practical ceiling:** tRPC routers with >50 procedures start showing IDE lag. The fix is splitting routers into sub-routers (which tRPC supports natively), not simplifying types. But know the ceiling exists before choosing tRPC for a 500-endpoint API.

### 63. Effect-TS -- Powerful Abstraction With Steep Type Complexity Cost

Effect-TS provides typed errors, dependency injection, and algebraic effect management. `Effect<A, E, R>` where all three parameters can be complex union types. The tradeoff: correct types with steep learning curve and opaque error messages.

**The boundary:** Effect-TS earns its complexity in applications with dozens of error types and complex dependency graphs (large backend services, financial systems). It's overkill for frontend applications, simple CRUD APIs, or teams without functional programming experience. The learning curve is the real cost -- not the runtime overhead.

### 64. Type Generation from Schemas -- Single Source of Truth Problems

Prisma generates types from schema; GraphQL codegen generates from schema; OpenAPI codegen generates from spec. Each is a different source of truth. When you use all three, the `User` type from Prisma and the `User` type from GraphQL are structurally similar but semantically different (nullable vs optional, null vs undefined).

**The senior move:** Designate one schema as the single source of truth and derive others. Database schema (Prisma) as source: generate API types from database types. API schema (OpenAPI) as source: generate client types from the spec. Don't let multiple code generators create competing `User` types -- the mapping bugs between them are subtle and silent.

### 65. The `@types` Lag Problem

`@types/react` may lag behind `react` by weeks or months. During that lag, TypeScript users either pin to the old React version, use `@ts-expect-error` on new APIs, or write local declaration overrides. For popular libraries this lag is short. For less popular libraries, `@types/` packages can be months behind or abandoned entirely.

**The strategy:** For critical dependencies, prefer libraries that bundle their own types (Zod, tRPC, Prisma, Effect). For libraries that rely on DefinitelyTyped, budget time for type lag after major version bumps. If you're a library author: bundle your types. Don't make your users depend on DefinitelyTyped volunteers.

---

## Migration

### 66. Gradual vs Big-Bang -- `allowJs` and `$TSFixMe`

Airbnb built `ts-migrate` -- a codemod pipeline that converts JS to TypeScript in one pass, introducing `$TSFixMe` aliases for `any` instead of blocking on typing. They converted 86% of their 6M-line monorepo this way. The alternative: file-by-file gradual migration with `allowJs: true`, converting files as they're touched. Gradual is safer but creates a multi-year half-TypeScript limbo.

**The judgment:** Big-bang with `$TSFixMe` for large codebases where the half-and-half state is more painful than temporary `any`. Gradual for smaller codebases or teams without the capacity for a dedicated migration sprint. Either way, track your `$TSFixMe`/`any` count and enforce a downward trend.

### 67. Strict Mode Migration -- Per-Flag, Not All at Once

Enabling `strict: true` on an existing codebase produces hundreds to thousands of errors. The VS Code team (500K+ lines) saw ~4,500 errors from `strictNullChecks` alone. Figma (1,162 files) saw 4,000+ errors. Both built custom tooling for the migration.

**The approach:** Enable one flag at a time. Start with `noImplicitAny` (forces explicit annotations that make later flags easier). Then `strictNullChecks` (finds real bugs -- both VS Code and Figma confirmed it caught production-impacting null errors). Then `strictBindCallApply`, `strictPropertyInitialization`, etc. Each flag in isolation produces a manageable error count. All at once produces despair.

### 68. `strictNullChecks` Migration Cascade

The specific challenge with `strictNullChecks`: errors cascade. Correctly annotating one function's return type as `T | undefined` immediately creates errors in all its callers. The callers' callers are then affected. VS Code found that the largest dependency cycle involved 500+ files -- nearly half the codebase -- making incremental per-module migration nearly impossible.

**The workaround:** Both VS Code and Figma used a technique of starting from leaf modules (those with no downstream dependents) and working inward. Figma built a custom dependency analyzer to identify the migration order. If your codebase has large dependency cycles, you may need to break the cycle first before migrating `strictNullChecks` incrementally.

### 69. Type Coverage as Metric -- Necessary but Not Sufficient

The `type-coverage` CLI measures what percentage of identifiers aren't `any`. It provides a proxy metric for migration progress and integrates with CI to prevent regressions. The caveat: high coverage with permissive types (large unions, excessive casts hidden behind intermediate types) provides false confidence. 95% type coverage means nothing if 20% of those typed values flow through an unsound `as` cast.

**The companion metric:** Track `@ts-expect-error` and `@ts-ignore` counts alongside type coverage. A codebase with 98% type coverage and 500 `@ts-ignore` directives has a different risk profile than one with 95% coverage and zero suppressions.

### 70. The `any` Budget -- Acceptable Percentage During Migration

During migration, some `any` is inevitable. The question is how much and for how long. Airbnb's approach: convert everything to TypeScript at once with liberal `any`, then progressively remove it. The progressive removal needs enforcement -- a CI check that fails if `any` count increases, or a ratchet that only allows the count to decrease.

**The signal:** Your `any` count has been flat for three months. The migration is stalled. Without active enforcement and allocated engineering time, `any` becomes permanent. Patreon's migration took seven years partly because `any` removal wasn't prioritized.

---

## Overengineering Patterns

### 71. Type Gymnastics vs Type Infrastructure -- The Distinction

Senior engineers distinguish "type gymnastics" (complex types that exist to demonstrate TypeScript mastery or solve a problem better handled at runtime) from "type infrastructure" (complex types maintained once and consumed many times that prevent a whole class of bugs for callers).

**The test:** Does the complex type reduce mistakes for people who didn't write it? If yes, it earns its complexity. If it only satisfies the author's cleverness, it doesn't. `Awaited<T>` is infrastructure -- every `async` function consumer benefits. A 30-line recursive conditional type that extracts nested form field paths for one component is gymnastics.

### 72. DRY Utility Type Chains -- Unreadable After Six Months

Teams that pursue DRY at the type level create chains like `ReturnType<InstanceType<typeof Foo>["bar"]>`. Six months later, nobody can mentally evaluate this without hovering in an IDE. It's also brittle: if `Foo` is refactored, the derived type silently shifts in ways that may or may not be correct.

**The alternative:** Name intermediate types. `type FooInstance = InstanceType<typeof Foo>; type BarReturn = ReturnType<FooInstance["bar"]>`. More lines, dramatically more readable. Or just write the concrete type directly if it's used in only one place. Three lines of explicit type definition is better than one line of unreadable type derivation.

### 73. Function Overloads When Unions Suffice

Function overloads are needed when the return type depends on the argument type: `function parse(x: string): string; function parse(x: number): number`. For simpler cases -- optional trailing parameters, or parameter unions with a consistent return type -- overloads add complexity without benefit.

**The lint check:** `@typescript-eslint/unified-signatures` flags overloads that could be a single signature with a union parameter. If the lint passes, you probably need the overloads. If it flags them, use unions.

### 74. Branded Types Everywhere -- Type Bureaucracy

Branding every primitive (`UserId`, `OrderId`, `EmailAddress`, `FirstName`, `LastName`, `StreetAddress`) requires constructor functions for each, explicit brand-stripping at serialization boundaries, and fighting `JSON.parse` which erases brands.

**The practical rule:** Brand primitives where confusion would cause a production incident (payment IDs, auth tokens, resource identifiers in multi-tenant systems). Don't brand primitives where the worst case is a confusing test failure. If you're spending more time writing brand constructors than the brands would save in prevented bugs, you've crossed the line.

---

## The Frontier

### 75. Node.js Type Stripping -- The Erasable/Non-Erasable Split

Node.js 23.6+ (stable in 24.3) strips TypeScript type annotations natively without a compiler. Erasable syntax (annotations, interfaces, `as`, `!`) works. Non-erasable syntax (`enum`, `namespace`, parameter properties) requires `--experimental-transform-types`. `import type` is required for type-only imports -- without it, Node.js treats it as a value import and throws.

**The implication:** For scripts, CLIs, and simple servers, you can run `.ts` files directly with `node --experimental-strip-types`. No `tsc`, no `tsx`, no build step. But `const enum` users and namespace users are locked out of this path. This is the strongest argument yet for abandoning `enum` in new code.

### 76. `using` / `await using` -- Explicit Resource Management

TC39 Stage 3, shipped in TypeScript 5.2. `using handle = getFileHandle()` calls `handle[Symbol.dispose]()` at end of scope, even if an exception is thrown. Analogous to C# `using`, Python `with`, Java try-with-resources. Replaces error-prone try/finally patterns for file handles, database connections, mutex locks.

**When to adopt:** In new code where resources need deterministic cleanup. Beyond leak prevention, it solves the double-error-loss problem: in `try/finally`, if cleanup in `finally` also throws, the original error is silently replaced. `Symbol.dispose` errors compose with the primary error via `SuppressedError`, preserving both. The main blocker is runtime support -- `Symbol.dispose` needs polyfilling in older Node.js versions.

### 77. Inferred Type Predicates -- The TS 5.5 Ergonomic Win

Before TS 5.5: `array.filter(x => x !== undefined)` returned `(T | undefined)[]` -- TypeScript couldn't see through the filter. After: TypeScript automatically infers `x is NonNullable<T>`. This eliminates the need for `(x): x is T => x !== undefined` boilerplate in most cases.

**The nuance:** The inference has strict "if and only if" semantics. `score => !!score` won't infer a predicate because `false` doesn't guarantee the value is `0` (could be falsy string or NaN). The inference is conservative by design -- it only fires when the narrowing is provably correct. For complex predicates, you still need explicit type guards.
