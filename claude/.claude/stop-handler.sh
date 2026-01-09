#!/bin/bash
echo "Stop hook called" >> /tmp/claude-notifications.log

# 標準入力からデータを受け取る（短時間のタイムアウト）
if read -t 1 stop_data; then
    # 追加の行があるかもしれないので、残りも読む
    while read -t 1 additional_line 2>/dev/null; do
        stop_data="$stop_data$additional_line"
    done
else
    stop_data=""
fi
echo "Stop data received: $stop_data" >> /tmp/claude-notifications.log

# ターミナル情報を取得
terminal_info=$(/Users/nagata/.claude/get-terminal-info.sh)
terminal_app=$(echo "$terminal_info" | jq -r '.app')
terminal_title=$(echo "$terminal_info" | jq -r '.title')
terminal_bundle=$(echo "$terminal_info" | jq -r '.bundle')

echo "Terminal info: $terminal_app - $terminal_title" >> /tmp/claude-notifications.log

# 動的な通知メッセージを生成
current_time=$(date '+%H:%M:%S')
current_dir=$(basename "$(pwd)")

# ディレクトリ情報付きメッセージを作成
base_message="Task completed\nin ${current_dir}"

if [[ -n "$stop_data" ]]; then
    # JSONデータが受け取れた場合
    session_short=$(echo "$stop_data" | jq -r '.session_id[:8]' 2>/dev/null)
    if [[ $? -eq 0 && -n "$session_short" && "$session_short" != "null" ]]; then
        notification_cmd="display notification \"${base_message}\" with title \"Claude Code - ${current_time}\" sound name \"Glass\""
        echo "Generated stop command: $notification_cmd" >> /tmp/claude-notifications.log
    else
        # JSON解析に失敗した場合のフォールバック
        notification_cmd="display notification \"${base_message}\" with title \"Claude Code - ${current_time}\" sound name \"Glass\""
        echo "Using fallback stop command: $notification_cmd" >> /tmp/claude-notifications.log
    fi
else
    # データが受け取れなかった場合
    notification_cmd="display notification \"${base_message}\" with title \"Claude Code - ${current_time}\" sound name \"Glass\""
    echo "Using default stop command: $notification_cmd" >> /tmp/claude-notifications.log
fi

# 通知のみ表示（クリック機能は技術的制限により削除）
full_cmd="$notification_cmd"

# ターミナルの状態をチェック
if /Users/nagata/.claude/check-terminal.sh; then
    echo "Playing beep for front terminal (stop)" >> /tmp/claude-notifications.log
    osascript -e "beep 1"
else
    echo "Showing notification for background (stop)" >> /tmp/claude-notifications.log
    osascript -e "$full_cmd"
fi

