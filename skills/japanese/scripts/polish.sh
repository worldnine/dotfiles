#!/usr/bin/env bash
#
# japanese/polish.sh — Antigravity CLI（agy / Gemini）に日本語を推敲させ、lint で検証する
#
#   polish.sh [オプション] <ファイル | ->
#
#   1. scripts/lint.py で「AI臭さ」を機械検出する（before）
#   2. その指摘をヒントとして agy のヘッドレス実行（-p）に渡す
#   3. 返ってきた修正案を差分で見せる
#   4. もう一度 lint を回し、指摘が解消したか・増えたかを数える
#
#   既定では元ファイルを書き換えない。
#
# オプション:
#   -m, --model NAME     agy --model に渡すモデル名（既定: agy の既定モデル）
#   -e, --effort LEVEL   推論の深さ low|medium|high（モデル名に effort が含まれる場合は無視）
#   -t, --timeout DUR    agy --print-timeout（既定: 5m）
#   -g, --genre NAME     lint のジャンル別閾値 business|essay|tech
#   -o, --output FILE    修正後の本文を FILE に書き出す（差分は常に表示）
#   -w, --write          修正後で元ファイルを上書きする（.bak.<日時> を残す）
#       --no-lint        lint のヒント渡しと検証をやめる
#       --policy-full    禁止語・翻訳調のカタログもプロンプトに同梱する
#   -p, --prompt TEXT    追加指示を1つ渡す
#       --dry-run        プロンプトを表示して終了（agy は呼ばない）
#   -h, --help           このヘルプ
#
# 環境変数:
#   AGY_BIN             agy の代わりに使う実行ファイル（既定: agy）
#   JA_POLISH_MODEL     既定モデルの上書き（既定: gemini-3.8-flash-medium）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
POLICY="$SKILL_DIR/prompts/policy.md"
LINT_PY="$SCRIPT_DIR/lint.py"

AGY_BIN="${AGY_BIN:-agy}"
MODEL="${JA_POLISH_MODEL:-gemini-3.8-flash-medium}"
EFFORT="medium"
EFFORT_EXPLICIT=0
AGY_TIMEOUT="5m"
GENRE=""
WRITE=0
OUTPUT=""
USE_LINT=1
POLICY_FULL=0
EXTRA=""
DRY_RUN=0
INPUT=""

# argv 経由でプロンプトを渡すため、ARG_MAX（macOS は約1MB）に対して余裕を持たせる
MAX_INPUT_BYTES=400000

usage() {
  cat <<'USAGE'
japanese/polish.sh — Antigravity CLI（agy / Gemini）に日本語を推敲させ、lint で検証する

  polish.sh [オプション] <ファイル | ->

  -m, --model NAME     agy --model に渡すモデル名（既定: gemini-3.8-flash-medium）
  -e, --effort LEVEL   推論の深さ low|medium|high（モデル名に effort が含まれる場合は無視）
  -t, --timeout DUR    agy --print-timeout（既定: 5m）
  -g, --genre NAME     lint のジャンル別閾値 business|essay|tech
  -o, --output FILE    修正後の本文を FILE に書き出す（差分は常に表示）
  -w, --write          修正後で元ファイルを上書きする（.bak.<日時> を残す）
      --no-lint        lint のヒント渡しと検証をやめる
      --policy-full    禁止語・翻訳調のカタログもプロンプトに同梱する
  -p, --prompt TEXT    追加指示を1つ渡す
      --dry-run        プロンプトを表示して終了（agy は呼ばない）
  -h, --help           このヘルプ

環境変数: AGY_BIN（agy の代わりに使う実行ファイル）
USAGE
}

die() { printf 'polish: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -m|--model)    MODEL="${2:?--model には値が必要です}"; shift 2 ;;
    -e|--effort)   EFFORT="${2:?--effort には値が必要です}"; EFFORT_EXPLICIT=1; shift 2 ;;
    -t|--timeout)  AGY_TIMEOUT="${2:?--timeout には値が必要です}"; shift 2 ;;
    -g|--genre)    GENRE="${2:?--genre には値が必要です}"; shift 2 ;;
    -o|--output)   OUTPUT="${2:?--output には値が必要です}"; shift 2 ;;
    -w|--write)    WRITE=1; shift ;;
    --no-lint)     USE_LINT=0; shift ;;
    --policy-full) POLICY_FULL=1; shift ;;
    -p|--prompt)   EXTRA="${2:?--prompt には値が必要です}"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    --)            shift; break ;;
    -)             INPUT="-"; shift ;;
    -*)            usage >&2; die "不明なオプション: $1" ;;
    *)             INPUT="$1"; shift ;;
  esac
done

[ -f "$POLICY" ] || die "校正ポリシーが見つかりません: ${POLICY}"

# モデル名に effort が含まれる（例: gemini-3.8-flash-medium）場合は、そちらを正とする
MODEL_EFFORT=""
case "$MODEL" in
  *-low)    MODEL_EFFORT="low" ;;
  *-medium) MODEL_EFFORT="medium" ;;
  *-high)   MODEL_EFFORT="high" ;;
esac
EFFORT_VIA_MODEL=0
if [ -n "$MODEL_EFFORT" ]; then
  if [ "$EFFORT_EXPLICIT" = 1 ] && [ "$EFFORT" != "$MODEL_EFFORT" ]; then
    printf 'polish: --effort %s は無視します（モデル名 %s が effort を含むため）\n' "$EFFORT" "$MODEL" >&2
  fi
  EFFORT="$MODEL_EFFORT"
  EFFORT_VIA_MODEL=1
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ja-polish.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# ---- 入力の準備 ----------------------------------------------------------
if [ -z "$INPUT" ] || [ "$INPUT" = "-" ]; then
  cat > "$TMP/orig.txt"
  ORIG_LABEL="(標準入力)"
else
  [ -f "$INPUT" ] || die "ファイルが見つかりません: ${INPUT}"
  cp "$INPUT" "$TMP/orig.txt"
  ORIG_LABEL="$INPUT"
fi
[ -s "$TMP/orig.txt" ] || die "入力が空です"

BYTES="$(wc -c < "$TMP/orig.txt" | tr -d ' ')"
[ "${BYTES}" -le "${MAX_INPUT_BYTES}" ] || die "入力が大きすぎます（${BYTES} バイト）。分割して実行してください"

# ---- 機械検出（before） --------------------------------------------------
LINT_OK=0
HINTS=""
LINT_NOTE=""
if [ "$USE_LINT" = 1 ]; then
  if [ -f "$LINT_PY" ] && command -v uv >/dev/null 2>&1; then
    LINT_ARGS=( --json )
    if [ -n "$GENRE" ]; then LINT_ARGS+=( --genre "$GENRE" ); fi
    if uv run "$LINT_PY" "${LINT_ARGS[@]}" "$TMP/orig.txt" > "$TMP/before.json" 2> "$TMP/lint.err"; then
      LINT_OK=1
      HINTS="$(python3 "$SCRIPT_DIR/lint_hints.py" "$TMP/before.json" 2>/dev/null || true)"
    else
      LINT_NOTE="lint をスキップしました（uv run lint.py が失敗。uv と sudachipy の導入を確認）"
    fi
  else
    LINT_NOTE="lint をスキップしました（uv が見つかりません）"
  fi
fi

# ---- プロンプトの組み立て ------------------------------------------------
{
  cat "$POLICY"

  if [ "$POLICY_FULL" = 1 ]; then
    for f in "$SKILL_DIR/references/forbidden-patterns.md" "$SKILL_DIR/references/translationese.md"; do
      if [ -f "$f" ]; then
        printf '\n## 参考カタログ: %s\n\n' "$(basename "$f")"
        sed -n '1,200p' "$f"
      fi
    done
  fi

  if [ -n "$HINTS" ]; then
    cat <<'HINT_HEADER'

## 機械検出の指摘（参考）

以下は機械的な検出器が「AI臭い」と指摘した箇所です。すべて直す必要はありません。文脈を見て本当に不自然な箇所だけ直し、指摘に引きずられて原文の意味や書き手の個性を壊さないこと。
HINT_HEADER
    printf '\n%s\n' "$HINTS"
  fi

  if [ -n "$EXTRA" ]; then
    printf '\n## 追加の指示\n\n%s\n' "$EXTRA"
  fi

  printf '\nツール（ファイル操作・コマンド実行・検索）は使わず、与えられた本文だけで作業してください。\n'
  printf '\n次が本文です。<doc> と </doc> の間が校正対象です。\n\n<doc>\n'
  cat "$TMP/orig.txt"
  printf '\n</doc>\n'
} > "$TMP/prompt.txt"

if [ "$DRY_RUN" = 1 ]; then
  echo "--- プロンプト（${TMP}/prompt.txt 相当） ---"
  cat "$TMP/prompt.txt"
  exit 0
fi

# ---- agy の実行 ----------------------------------------------------------
command -v "$AGY_BIN" >/dev/null 2>&1 || die "agy が見つかりません（brew install --cask antigravity-cli）"

ARGS=( -p "$(cat "$TMP/prompt.txt")" --print-timeout "$AGY_TIMEOUT" )
if [ -n "$MODEL" ]; then ARGS+=( --model "$MODEL" ); fi
if [ "$EFFORT_VIA_MODEL" = 0 ]; then ARGS+=( --effort "$EFFORT" ); fi

# ワークスペースを空にして、本文以外のファイルを触らせない
mkdir -p "$TMP/work"
set +e
( cd "$TMP/work" && "$AGY_BIN" "${ARGS[@]}" ) > "$TMP/out.txt" 2> "$TMP/err.txt"
STATUS=$?
set -e

if grep -q -i 'please sign in\|not logged into antigravity' "$TMP/out.txt" "$TMP/err.txt" 2>/dev/null; then
  die "agy が未サインインです。実端末で agy を起動し、ブラウザでサインインしてください（agy models で確認できる。一度成功すればキーチェーンに保存され、以後は聞かれません）"
fi

if grep -q 'no output produced' "$TMP/out.txt" "$TMP/err.txt" 2>/dev/null; then
  die "agy がツール呼び出しで止まりました（ヘッドレスでは権限を確認できないため自動拒否されます）。追加指示に「ツールは使わず本文だけを出力する」と明記するか、TUI 側で permissions を設定してください"
fi

if [ "${STATUS}" -ne 0 ]; then
  tail -n 15 "$TMP/err.txt" >&2 || true
  die "agy の実行に失敗しました（exit ${STATUS}）"
fi
[ -s "$TMP/out.txt" ] || die "agy の出力が空でした（--dry-run でプロンプトを確認してください）"

# ---- 出力の整形（前置きやコードフェンスを落とす） ------------------------
python3 - "$TMP/out.txt" "$TMP/revised.txt" <<'PY'
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read().replace("\r\n", "\n").strip("\n")
fence = re.match(r"^```[^\n]*\n(.*)\n```$", text, re.S)
if fence:
    text = fence.group(1)
open(dst, "w", encoding="utf-8").write(text + "\n")
PY

# ---- 差分 ----------------------------------------------------------------
echo "=== 推敲の差分（${ORIG_LABEL} / model=${MODEL} effort=${EFFORT}） ==="
if diff -q "$TMP/orig.txt" "$TMP/revised.txt" >/dev/null; then
  echo "変更なし（agy は手を入れませんでした）"
else
  diff -u --label "$ORIG_LABEL" --label "${ORIG_LABEL}（推敲後）" "$TMP/orig.txt" "$TMP/revised.txt" || true
fi

# ---- 検証（after）: 指摘が減ったか ---------------------------------------
if [ "$LINT_OK" = 1 ] && [ -s "$TMP/revised.txt" ]; then
  LINT_ARGS=( --json --baseline "$TMP/before.json" )
  if [ -n "$GENRE" ]; then LINT_ARGS+=( --genre "$GENRE" ); fi
  if uv run "$LINT_PY" "${LINT_ARGS[@]}" "$TMP/revised.txt" > "$TMP/after.json" 2>/dev/null; then
    echo
    echo "=== AI臭さの検証（lint before → after） ==="
    python3 - "$TMP/before.json" "$TMP/after.json" <<'PY'
import json
import sys

before = json.load(open(sys.argv[1], encoding="utf-8"))
after = json.load(open(sys.argv[2], encoding="utf-8"))
s = after.get("baseline", {}).get("summary", {})
b = before.get("stats", {}).get("total_findings", 0)
a = after.get("stats", {}).get("total_findings", 0)
print(f"検出件数: {b} → {a}（解消 {s.get('resolved', 0)} / 新規 {s.get('new', 0)} / 継続 {s.get('persisting', 0)}）")
for f in after.get("findings", []):
    if f.get("status") == "new":
        detail = " ".join((f.get("detail") or "").split())
        print(f"  [新規] L{f.get('line')} {detail[:90]}")
        print(f"         該当: {' '.join((f.get('excerpt') or '').split())[:60]}")
PY
  else
    LINT_NOTE="after の lint に失敗しました（検証はスキップ）"
  fi
fi

# ---- 反映 ----------------------------------------------------------------
if [ -n "$OUTPUT" ]; then
  cp "$TMP/revised.txt" "$OUTPUT"
  printf '\n修正後を書き出しました: %s\n' "$OUTPUT" >&2
fi

if [ "$WRITE" = 1 ]; then
  [ "$ORIG_LABEL" = "(標準入力)" ] && die "--write は標準入力では使えません"
  BACKUP="$INPUT.bak.$(date +%Y%m%d%H%M%S)"
  cp "$INPUT" "$BACKUP"
  cp "$TMP/revised.txt" "$INPUT"
  printf '上書きしました: %s（バックアップ: %s）\n' "$INPUT" "$BACKUP" >&2
fi

if [ -n "$LINT_NOTE" ]; then printf '\n%s\n' "$LINT_NOTE" >&2; fi
