#!/bin/bash

# 現在のターミナルアプリを検出してタイトルとアプリ名を取得する
frontapp=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')

terminal_app=""
terminal_title=""
terminal_bundle=""

if [[ "$frontapp" =~ iTerm ]]; then
    terminal_app="iTerm2"
    terminal_title=$(osascript -e 'tell application "iTerm2" to get name of current tab of current window' 2>/dev/null || echo "iTerm2 Tab")
    terminal_bundle="com.googlecode.iterm2"
elif [[ "$frontapp" =~ Terminal ]]; then
    terminal_app="Terminal"
    terminal_title=$(osascript -e 'tell application "Terminal" to get name of front window' 2>/dev/null || echo "Terminal Window")
    terminal_bundle="com.apple.Terminal"
elif [[ "$frontapp" =~ [Gg]hostty ]]; then
    terminal_app="Ghostty"
    # GhosttyはAppleScriptサポートがないので、環境変数やプロセス情報から取得を試みる
    if [[ -n "$GHOSTTY_WINDOW_TITLE" ]]; then
        terminal_title="$GHOSTTY_WINDOW_TITLE"
    else
        # プロセス情報から取得を試みる（フォールバック）
        terminal_title=$(ps -p $PPID -o command= | head -1 | cut -d' ' -f1 | xargs basename)
        if [[ -z "$terminal_title" ]]; then
            terminal_title="Ghostty Window"
        fi
    fi
    terminal_bundle="com.mitchellh.ghostty"
else
    # その他のターミナルアプリやプロセスの場合
    terminal_app="Unknown"
    terminal_title="Terminal"
    terminal_bundle=""
fi

# JSON形式で結果を出力
echo "{\"app\":\"$terminal_app\",\"title\":\"$terminal_title\",\"bundle\":\"$terminal_bundle\"}"