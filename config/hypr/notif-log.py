#!/usr/bin/env python3
# Pretty-print persisted notifications from AstalNotifd (HyprPanel's daemon).
#
# AstalNotifd serializes every non-transient notification to the GSettings key
# /io/astal/notifd/notifications. Parsing dconf's GVariant text output here
# avoids a pygobject dependency.
import re
import subprocess
import sys
from datetime import datetime
from html import unescape


def read_dconf() -> str:
    r = subprocess.run(
        ["dconf", "read", "/io/astal/notifd/notifications"],
        capture_output=True, text=True, check=False,
    )
    return r.stdout.strip()


def parse_string(text: str, i: int) -> tuple[str, int]:
    # Single-quoted GVariant string at text[i] == "'".
    assert text[i] == "'"
    out = []
    i += 1
    while i < len(text):
        c = text[i]
        if c == "\\":
            nxt = text[i + 1]
            out.append({"n": "\n", "t": "\t", "r": "\r"}.get(nxt, nxt))
            i += 4 if nxt == "x" else 2
            if nxt == "x":
                out[-1] = chr(int(text[i - 2:i], 16))
        elif c == "'":
            return "".join(out), i + 1
        else:
            out.append(c)
            i += 1
    raise ValueError("unterminated string")


def find_str(record: str, key: str) -> str | None:
    pat = f"'{key}': <'"
    idx = record.find(pat)
    if idx == -1:
        return None
    return parse_string(record, idx + len(pat) - 1)[0]


def find_int(record: str, key: str) -> int | None:
    m = re.search(rf"'{re.escape(key)}': <(?:int64|uint32|int32|uint64)\s+(-?\d+)>", record)
    return int(m.group(1)) if m else None


def split_records(text: str) -> list[str]:
    text = text.strip()
    if not text or text == "@av []":
        return []
    if text.startswith("@av "):
        text = text[4:].strip()
    if not (text.startswith("[") and text.endswith("]")):
        return []
    body, records, depth, in_str, start, i = text[1:-1], [], 0, False, 0, 0
    while i < len(body):
        c = body[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == "'":
                in_str = False
        elif c == "'":
            in_str = True
        elif c in "<[{":
            depth += 1
        elif c in ">]}":
            depth -= 1
        elif c == "," and depth == 0:
            records.append(body[start:i].strip())
            start = i + 1
        i += 1
    tail = body[start:].strip()
    if tail:
        records.append(tail)
    return records


TAG_RE = re.compile(r"<[^>]+>")


def strip_markup(s: str) -> str:
    return unescape(TAG_RE.sub("", s))


def main() -> int:
    entries = []
    for r in split_records(read_dconf()):
        entries.append((
            find_int(r, "time") or 0,
            find_str(r, "app-name") or "?",
            find_str(r, "summary") or "",
            find_str(r, "body") or "",
        ))
    entries.sort(reverse=True)
    if not entries:
        print("(no notifications)")
        return 0
    for ts, app, summary, body in entries:
        when = datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S") if ts else "----"
        print(f"[{when}] {app}")
        if summary:
            print(f"  {strip_markup(summary)}")
        for line in (strip_markup(body).splitlines() or ([""] if body else [])):
            print(f"    {line}")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
