#!/bin/bash
# Stop Hookから起動され、最新の対話履歴を一時ファイルに書き出すスクリプト

# 一時ファイルのパス
TMP_FILE="/tmp/claude_tweet_source.txt"

# 標準入力からコンテキストJSONを受け取る (Stopフックでは空の場合もある)
CONTEXT=$(cat)
PROJECT_DIR=$(echo "$CONTEXT" | jq -r '.project_dir // ""')

# デバッグログ（一時的にファイルに出力）
echo "$(date): Hook実行 - CONTEXT: $CONTEXT" >> /tmp/hook_debug.log
echo "$(date): Hook実行 - PROJECT_DIR: $PROJECT_DIR" >> /tmp/hook_debug.log

# プロジェクトディレクトリが取得できない場合はホームディレクトリを基準にする
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR=$HOME
fi

# プロジェクトに対応する履歴ディレクトリを探す
# Claude Codeのプロジェクトディレクトリ命名規則に基づいて検索
# 実際の命名パターンに合わせて修正: /Users/nagata/.claude → -Users-nagata--claude
if [[ "$PROJECT_DIR" == *"/.claude" ]]; then
  # .claudeディレクトリの場合は特別処理（ドット→ダブルハイフン）
  PROJECT_ENCODED=$(echo "$PROJECT_DIR" | sed 's|/|-|g' | sed 's|-\.claude|--claude|g')
else
  # その他の場合は通常処理
  PROJECT_ENCODED=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
fi
HISTORY_DIR=$(find "$HOME/.claude/projects/" -maxdepth 1 -type d -name "*${PROJECT_ENCODED}*" | head -n 1)

if [ ! -d "$HISTORY_DIR" ]; then
  # 見つからなければ何もしない
  exit 0
fi

LATEST_SESSION=$(ls -t "$HISTORY_DIR"/*.jsonl | head -n 1)

if [ -z "$LATEST_SESSION" ]; then
  exit 0
fi

# 最新のやり取り（ユーザーとアシスタントのペア）を抽出
# 時系列順で自然な対話を保持し、バランス良くQ&Aを含める統合クエリ
jq -r '
  select(.type == "user" or .type == "assistant") |
  select(
    (.type == "user" and .message.content != null and (.message.content | type) == "string") or
    (.type == "assistant" and .message.content[0].type == "text")
  ) |
  if .type == "user" then
    "\(.timestamp)|||Q: \(.message.content)"
  else
    "\(.timestamp)|||A: \(.message.content[0].text)"
  end
' "$LATEST_SESSION" 2>/dev/null | sort | cut -d'|' -f4- | tail -n 15 > "$TMP_FILE"