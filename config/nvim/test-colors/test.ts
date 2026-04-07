// Single-line comment
/*
 * Multi-line comment
 * TypeScript syntax showcase
 */

// Imports / modules
import { EventEmitter } from "node:events";
import type { IncomingMessage } from "node:http";

// Constants
const MAX_RETRIES = 5 as const;
const PI: number = 3.14159;
const GREETING = "hello\tworld\n\"quoted\"";
const TEMPLATE = `multi
  line template ${PI.toFixed(2)}`;

// Type aliases and interfaces
type Status = "ok" | "error" | "timeout";

interface Identifiable {
    readonly id: string;
}

interface Config extends Identifiable {
    host: string;
    port: number;
    tags?: string[];
}

// Generic type
type Result<T, E = Error> = { ok: true; value: T } | { ok: false; error: E };

// Enum
enum Direction {
    Up    = "UP",
    Down  = "DOWN",
    Left  = "LEFT",
    Right = "RIGHT",
}

// Decorator (experimental)
function log(target: unknown, key: string, descriptor: PropertyDescriptor) {
    const original = descriptor.value as (...args: unknown[]) => unknown;
    descriptor.value = function (...args: unknown[]) {
        console.log(`[${key}] called with`, args);
        return original.apply(this, args);
    };
    return descriptor;
}

// Generic class with constructor, fields, methods
class Queue<T> {
    private items: T[] = [];
    public readonly label: string;

    constructor(label: string) {
        this.label = label;
    }

    push(item: T): this {
        this.items.push(item);
        return this;
    }

    pop(): T | undefined {
        return this.items.pop();
    }

    get size(): number {
        return this.items.length;
    }
}

// Class with inheritance
class PriorityQueue<T> extends Queue<T> {
    private comparator: (a: T, b: T) => number;

    constructor(label: string, comparator: (a: T, b: T) => number) {
        super(label);
        this.comparator = comparator;
    }
}

// Async/await + error handling + optional chaining + nullish coalescing
async function fetchJson<T>(url: string, retries = MAX_RETRIES): Promise<Result<T>> {
    for (let attempt = 0; attempt < retries; attempt++) {
        try {
            const res = await fetch(url);
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            const data = (await res.json()) as T;
            return { ok: true, value: data };
        } catch (err) {
            if (attempt === retries - 1) {
                return { ok: false, error: err instanceof Error ? err : new Error(String(err)) };
            }
        }
    }
    return { ok: false, error: new Error("unreachable") };
}

// Utility types, mapped types, conditional types
type Readonly<T> = { readonly [K in keyof T]: T[K] };
type Nullable<T> = T extends object ? { [K in keyof T]: T[K] | null } : T | null;
type IsString<T> = T extends string ? true : false;

// Type narrowing, discriminated union, satisfies
function handleResult<T>(result: Result<T>): T {
    if (!result.ok) throw result.error;
    return result.value;
}

// Arrow functions, destructuring, spread, rest
const clamp = (value: number, lo: number, hi: number): number =>
    Math.max(lo, Math.min(hi, value));

const merge = <T extends object>(...sources: Partial<T>[]): T =>
    Object.assign({} as T, ...sources);

// Regex, template literal types
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
type EventName = `on${Capitalize<string>}`;

// Optional chaining and nullish coalescing operators
function getPort(cfg: Config | null): number {
    return cfg?.port ?? 3000;
}

// Bitwise + arithmetic operators
function pack(flags: number[]): number {
    return flags.reduce((acc, f) => acc | f, 0) & 0xFF;
}

// Main entry
async function main(): Promise<void> {
    const q = new Queue<number>("nums");
    q.push(1).push(2).push(3);
    console.log(`size: ${q.size}, last: ${q.pop()}`);

    const cfg: Config = { id: "1", host: "localhost", port: 8080, tags: ["api"] };
    console.log(cfg.tags?.[0] ?? "none");
    console.log(getPort(null));
    console.log(Direction.Up);
    console.log(pack([1, 2, 4]));

    const result = await fetchJson<{ name: string }>("https://example.com/api");
    if (result.ok) {
        console.log(result.value.name);
    }
}

main().catch(console.error);
