#!/bin/bash
# 通知内容を受け取る
notification_data=$(cat)
echo "Received notification: $notification_data" >> /tmp/claude-notifications.log

# JSONから情報を抽出
message=$(echo "$notification_data" | jq -r '.message // ""')
cwd=$(echo "$notification_data" | jq -r '.cwd // ""')
title=$(echo "$notification_data" | jq -r '.title // ""')

# メッセージの英語化
if [[ "$message" == *"permission to use Bash"* ]]; then
    english_message="Claude requests Bash permission"
else
    english_message="$message"
fi

# ディレクトリ情報を追加
if [[ -n "$cwd" ]]; then
    project_name=$(basename "$cwd")
    english_message="${english_message}\nin ${project_name}"
fi

# jqで通知コマンドを生成
notification_cmd="display notification \"$english_message\" with title \"Claude Code\" sound name \"Glass\""
echo "Generated command: $notification_cmd" >> /tmp/claude-notifications.log

# ターミナルの状態をチェック
if /Users/nagata/.claude/check-terminal.sh; then
    echo "Playing beep for front terminal" >> /tmp/claude-notifications.log
    osascript -e "beep 1"
else
    echo "Showing notification for background" >> /tmp/claude-notifications.log
    osascript -e "$notification_cmd"
fi