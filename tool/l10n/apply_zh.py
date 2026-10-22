#!/usr/bin/env python3
"""Build-time Simplified Chinese patch for e1547.

The fork keeps tracking upstream one to one: the translation itself lives in
``tool/l10n/zh_cn.json`` and is applied to the working tree right before
``flutter build`` runs. Nothing is committed back, so pulling upstream never
conflicts and every translation change is a one line diff in the dictionary.

Usage::

    python3 tool/l10n/apply_zh.py            # patch lib/**/*.dart in place
    python3 tool/l10n/apply_zh.py --dry-run  # only print what would change

Only plain, single token string literals are touched:

* generated files (``*.g.dart``, ``*.freezed.dart``, ``*.drift.dart``) are skipped
* comments are skipped
* string interpolation blocks (``${...}``) are skipped, simple ``$name`` is fine
* literals that are followed by ``:`` (map keys) or that sit on a line dealing
  with routes, payloads, headers or storage keys are skipped
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "lib"
DICTIONARY = Path(__file__).resolve().parent / "zh_cn.json"

SKIP_SUFFIXES = (".g.dart", ".freezed.dart", ".drift.dart")

# Literals on these lines describe data (routes, API payloads, headers,
# storage keys, ...) and must never be translated.
DENY_TOKENS = (
    "path:",
    "group:",
    "key:",
    "id:",
    "type:",
    "value:",
    "query",
    "param",
    "http",
    "Uri",
    "applicationId",
    "assets/",
    ".dart",
    ".json",
    ".png",
    ".ttf",
    "json",
    "ContentType",
    "header",
    "Authorization",
    "User-Agent",
    "==",
)


def _skip_interpolation(src: str, index: int) -> int:
    """Return the index right after the ``}`` closing a ``${`` block."""
    depth = 0
    length = len(src)
    while index < length:
        char = src[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index + 1
        elif char in "'\"":
            quote = char
            index += 1
            while index < length:
                inner = src[index]
                if inner == "\\":
                    index += 2
                    continue
                if inner == quote:
                    break
                if inner == "$" and index + 1 < length and src[index + 1] == "{":
                    index = _skip_interpolation(src, index + 1)
                    continue
                index += 1
        index += 1
    return length


def iter_literals(src: str):
    """Yield ``(content_start, content_end, content, is_simple)`` tuples."""
    index = 0
    length = len(src)
    while index < length:
        char = src[index]
        if char == "/" and index + 1 < length and src[index + 1] == "/":
            newline = src.find("\n", index)
            if newline == -1:
                return
            index = newline
            continue
        if char == "/" and index + 1 < length and src[index + 1] == "*":
            end = src.find("*/", index + 2)
            index = length if end == -1 else end + 2
            continue
        if char not in "'\"":
            index += 1
            continue

        previous = src[index - 1] if index > 0 else ""
        raw = previous == "r" and (
            index < 2 or not (src[index - 2].isalnum() or src[index - 2] in "_$")
        )

        cursor = index + 1
        simple = not raw
        while cursor < length:
            inner = src[cursor]
            if inner == "\\" and not raw:
                simple = False
                cursor += 2
                continue
            if inner == char:
                break
            if inner == "$" and not raw:
                if cursor + 1 < length and src[cursor + 1] == "{":
                    simple = False
                    cursor = _skip_interpolation(src, cursor + 1)
                    continue
            cursor += 1

        yield index + 1, cursor, src[index + 1 : cursor], simple
        index = cursor + 1


def patch_source(src: str, table: dict, hits: dict) -> tuple:
    edits = []
    for start, end, content, simple in iter_literals(src):
        if not simple or not content or "\n" in content:
            continue
        replacement = table.get(content)
        if replacement is None:
            continue

        line_start = src.rfind("\n", 0, start) + 1
        line_end = src.find("\n", end)
        if line_end == -1:
            line_end = len(src)
        line = src[line_start:line_end]
        if line.lstrip().startswith(("//", "///", "*", "/*")):
            continue
        if any(token in line for token in DENY_TOKENS):
            continue
        if any(token in content for token in DENY_TOKENS):
            continue

        # A literal directly followed by `:` is a map key, not user facing text.
        following = src[end + 1 : end + 40].lstrip()
        if following.startswith(":") and not following.startswith("::"):
            continue

        edits.append((start, end, replacement))
        hits[content] = hits.get(content, 0) + 1

    if not edits:
        return src, 0

    for start, end, replacement in reversed(edits):
        src = src[:start] + replacement + src[end:]
    return src, len(edits)


def main() -> int:
    dry_run = "--dry-run" in sys.argv
    table = json.loads(DICTIONARY.read_text(encoding="utf-8"))["strings"]

    hits: dict = {}
    changed_files = []
    total = 0

    for path in sorted(LIB.rglob("*.dart")):
        if path.name.endswith(SKIP_SUFFIXES):
            continue
        src = path.read_text(encoding="utf-8")
        patched, count = patch_source(src, table, hits)
        if count == 0:
            continue
        changed_files.append((path.relative_to(ROOT).as_posix(), count))
        total += count
        if not dry_run:
            path.write_text(patched, encoding="utf-8")

    stale = [key for key in table if key not in hits]

    print(f"[l10n] translations applied: {total}")
    print(f"[l10n] files touched: {len(changed_files)}")
    for name, count in changed_files:
        print(f"  {count:>4}  {name}")
    if stale:
        print(f"[l10n] dictionary entries not found in the source: {len(stale)}")
        for key in stale:
            print(f"  - {key!r}")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write("## 汉化补丁\n\n")
            handle.write(f"* 替换字符串：**{total}**\n")
            handle.write(f"* 涉及文件：**{len(changed_files)}**\n")
            handle.write(f"* 词典条目：**{len(table)}**，未匹配：**{len(stale)}**\n\n")
            handle.write("| 次数 | 文件 |\n| --- | --- |\n")
            for name, count in changed_files:
                handle.write(f"| {count} | `{name}` |\n")
            if stale:
                handle.write("\n<details><summary>未匹配的词典条目</summary>\n\n")
                for key in stale:
                    handle.write(f"* `{key}`\n")
                handle.write("\n</details>\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
