# Single-line comment
"""
Module-level docstring.
Multi-line, shows up as a string.
"""

from __future__ import annotations

import asyncio
import re
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from typing import ClassVar, Generic, TypeVar, override

# Constants
MAX_RETRIES: int = 5
PI: float = 3.14159
GREETING: str = "hello"
NOTHING: None = None

T = TypeVar("T")

# Decorator
def retry(times: int = 3):  # pyright: ignore[reportUnknownParameterType]
    def decorator(func):  # pyright: ignore[reportUnknownParameterType, reportMissingParameterType]
        async def wrapper(*args, **kwargs):  # pyright: ignore[reportUnknownParameterType, reportMissingParameterType]
            for attempt in range(times):
                try:
                    return await func(*args, **kwargs)  # pyright: ignore[reportUnknownVariableType]
                except Exception as exc:
                    if attempt == times - 1:
                        raise
                    print(f"Retrying after error: {exc!r}")
        return wrapper  # pyright: ignore[reportUnknownVariableType]
    return decorator  # pyright: ignore[reportUnknownVariableType]


# Dataclass with class variable, field defaults, type annotations
@dataclass
class Config:
    """Application configuration."""

    DEFAULT_PORT: ClassVar[int] = 8080

    host: str
    port: int = field(default=DEFAULT_PORT)
    tags: list[str] = field(default_factory=list)

    def endpoint(self) -> str:
        return f"http://{self.host}:{self.port}"

    @override
    def __repr__(self) -> str:
        return f"Config(host={self.host!r}, port={self.port})"


# Generic class
class Queue(Generic[T]):
    def __init__(self) -> None:
        self._items: list[T] = []

    def push(self, item: T) -> None:
        self._items.append(item)

    def pop(self) -> T:
        return self._items.pop()

    def __len__(self) -> int:
        return len(self._items)


# String variety: raw, f-string, multiline, escapes, regex
RAW = r"raw\nstring \d+"
ESCAPED = "tab\there\nnewline \"quoted\" \\"
PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")

def describe(name: str, value: object) -> str:
    """Return a formatted description using an f-string."""
    return f"[{name!r:>12}] = {value!r}"


# Async generator with error handling
@retry(times=3)
async def fetch_pages(urls: list[str]) -> AsyncIterator[bytes]:
    import aiohttp  # local import  # pyright: ignore[reportMissingImports]
    async with aiohttp.ClientSession() as session:  # pyright: ignore[reportUnknownMemberType, reportUnknownVariableType]
        for url in urls:
            async with session.get(url) as response:  # pyright: ignore[reportUnknownVariableType, reportUnknownMemberType]
                if response.status != 200:  # pyright: ignore[reportUnknownMemberType]
                    raise ValueError(f"Bad status {response.status} for {url!r}")  # pyright: ignore[reportUnknownMemberType]
                yield await response.read()  # pyright: ignore[reportUnknownMemberType]


# Comprehensions, walrus, builtins
def process(items: list[str | None]) -> list[str]:
    cleaned = [s.strip() for s in items if s is not None and s.strip()]
    lengths = {s: len(s) for s in cleaned}
    unique = list({s.lower() for s in cleaned})

    if result := [s for s in unique if len(s) > 3]:
        return sorted(result, key=lambda x: lengths.get(x, 0), reverse=True)
    return []


# Operators: arithmetic, comparison, bitwise, ternary, walrus
def calculate(a: int, b: int) -> int | None:
    if a == 0 or b < 0:
        return None
    result = (a + b) * (a - b) // max(a % b, 1)
    return result >> 2 & 0xFF if result > 0 else ~result


async def main() -> None:
    cfg = Config(host="localhost", tags=["web", "api"])
    print(cfg.endpoint())
    print(repr(cfg))

    q: Queue[int] = Queue()
    for n in range(5):
        q.push(n * 2)
    print(q.pop())

    items: list[str | None] = ["  hello ", None, "world", "", "hi"]
    print(process(items))
    print(describe("pi", PI))
    print(True, False, None)


if __name__ == "__main__":
    asyncio.run(main())
