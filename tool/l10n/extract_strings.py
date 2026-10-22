#!/usr/bin/env python3
"""Dump every user facing string literal that has no translation yet.

The output is committed back by CI so the translation can be written in
batches without cloning the repository. Rows are grouped by module and sorted
by frequency, UI looking literals first.

Usage::

    python3 tool/l10n/extract_strings.py > tool/l10n/extracted.txt
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from apply_zh import (  # noqa: E402
    LIB,
    ROOT,
    SKIP_SUFFIXES,
    UI_MARKERS,
    iter_literals,
    literal_is_translatable,
    load_dictionary,
)


def main() -> int:
    table = load_dictionary()

    entries: dict = {}
    for path in sorted(LIB.rglob("*.dart")):
        if path.name.endswith(SKIP_SUFFIXES):
            continue
        src = path.read_text(encoding="utf-8")
        relative = path.relative_to(ROOT).as_posix()
        module = relative.split("/")[1] if relative.count("/") > 1 else "lib"
        for start, end, content, _plain in iter_literals(src):
            if content in table:
                continue
            if not literal_is_translatable(src, start, end, content):
                continue
            line_end = src.find("\n", end)
            line = src[
                src.rfind("\n", 0, start) + 1 : line_end if line_end != -1 else len(src)
            ]
            is_ui = any(marker in line for marker in UI_MARKERS)
            if content.isdigit() or len(content) < 2:
                continue

            if content in entries:
                entries[content][0] += 1
            else:
                entries[content] = [1, module, relative, is_ui]

    rows = [
        (count, module, path, is_ui, content)
        for content, (count, module, path, is_ui) in entries.items()
    ]
    rows.sort(key=lambda row: (not row[3], row[1], -row[0], row[4]))

    ui_rows = sum(1 for row in rows if row[3])
    print("# e1547 待翻译字符串清单")
    print("#")
    print("# 这是由 tool/l10n/extract_strings.py 自动生成的文件，请勿手工编辑。")
    print("# 格式：出现次数 | 类型 | 字面量 | 示例文件")
    print("# 补充翻译时，把字面量原样作为 key 写进 tool/l10n/zh_cn*.json 的 strings 即可。")
    print("#")
    print(f"# 未翻译条目：{len(rows)}（疑似界面文案 {ui_rows}，其余可能是技术性字符串）")
    print()
    for count, module, path, is_ui, content in rows:
        flag = "UI" if is_ui else "--"
        print(f"{count:5d}  {flag}  {content}  |  {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
