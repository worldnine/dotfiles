#!/usr/bin/env python3
"""scripts/lint.py --json の出力を、agy に渡す短いヒント行に変換する。

標準入力に lint.py の JSON、または引数にそのファイルパスを取る。
"""

import json
import sys

MAX_FINDINGS = 40
MAX_DETAIL = 100
SEVERITY_ORDER = {"error": 0, "warn": 1, "info": 2}


def clip(text, limit=MAX_DETAIL):
    text = " ".join((text or "").split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def main() -> int:
    raw = open(sys.argv[1], encoding="utf-8").read() if len(sys.argv) > 1 else sys.stdin.read()
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return 0

    findings = data.get("findings") or []
    if not findings:
        return 0

    findings.sort(key=lambda f: (SEVERITY_ORDER.get(f.get("severity", "info"), 3), f.get("line") or 0))

    lines = []
    for f in findings[:MAX_FINDINGS]:
        loc = f"L{f['line']}" if f.get("line") else "L?"
        lines.append(f"- {loc} [{f.get('category', '?')}] {clip(f.get('detail'))} / 該当: {clip(f.get('excerpt'), 60)}")
    if len(findings) > MAX_FINDINGS:
        lines.append(f"- （ほか {len(findings) - MAX_FINDINGS} 件）")

    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
