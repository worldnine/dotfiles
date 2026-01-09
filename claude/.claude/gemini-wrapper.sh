#!/bin/bash

# 環境変数ファイルを検索して読み込む関数
find_and_load_env() {
    local current_dir="$(pwd)"
    local env_loaded=false
    
    # 現在のディレクトリからルートまで遡る
    while [ "$current_dir" != "/" ]; do
        # .gemini/.env をチェック
        if [ -f "$current_dir/.gemini/.env" ]; then
            source "$current_dir/.gemini/.env"
            env_loaded=true
            echo -e "\033[38;5;242m[ENV] Loaded: $current_dir/.gemini/.env\033[0m" >&2
            break
        fi
        # .env をチェック
        if [ -f "$current_dir/.env" ]; then
            source "$current_dir/.env"
            env_loaded=true
            echo -e "\033[38;5;242m[ENV] Loaded: $current_dir/.env\033[0m" >&2
            break
        fi
        # 親ディレクトリへ
        current_dir="$(dirname "$current_dir")"
    done
    
    # 見つからない場合はホームディレクトリをチェック
    if [ "$env_loaded" = false ]; then
        if [ -f "$HOME/.gemini/.env" ]; then
            source "$HOME/.gemini/.env"
            echo -e "\033[38;5;242m[ENV] Loaded: $HOME/.gemini/.env\033[0m" >&2
        elif [ -f "$HOME/.env" ]; then
            source "$HOME/.env"
            echo -e "\033[38;5;242m[ENV] Loaded: $HOME/.env\033[0m" >&2
        fi
    fi
}

# 環境変数を読み込む
find_and_load_env

# 検索クエリを抽出して表示
search_query=""
if [[ "$*" == *"WebSearch:"* ]]; then
    search_query=$(echo "$*" | sed 's/.*WebSearch: *//; s/^['"'"'"]*//; s/['"'"'"]*$//')
    echo -e "\033[48;5;195m\033[38;5;201m 🔍 Searching: \"$search_query\" \033[0m" >&2
else
    echo -e "\033[48;5;195m\033[38;5;201m 🔍 Searching with Gemini... \033[0m" >&2
fi

# 一時ファイルでgeminiの出力を保存
temp_file="/tmp/gemini_output_$$"
quota_exceeded=false

# geminiコマンドを実行し、リアルタイムで429エラーを監視
gemini "$@" 2>&1 | tee "$temp_file" | while IFS= read -r line; do
    # 出力を標準出力に流す
    echo "$line"
    # 429エラーまたはクォータ制限を検出
    if echo "$line" | grep -q "status 429\|Quota exceeded\|rateLimitExceeded"; then
        # geminiプロセスをkill
        pkill -f "gemini.*" 2>/dev/null
        # 429検出フラグを設定
        echo "429_detected" > "/tmp/gemini_status_$$"
        break
    fi
done

# 429エラーが検出された場合の処理
if [ -f "/tmp/gemini_status_$$" ]; then
    echo -e "\033[48;5;224m\033[38;5;160m ⚠️  Gemini quota exceeded \033[0m" >&2
    rm -f "/tmp/gemini_status_$$" "$temp_file"
    
    # WebSearchクエリを抽出（引数から）
    if [[ "$*" == *"WebSearch:"* ]]; then
        query=$(echo "$*" | sed 's/.*WebSearch: *//; s/['"'"'"]//g')
        echo -e "\033[48;5;153m\033[30m 🔄 Falling back to WebSearch... \033[0m" >&2
        
        # フォールバックフラグを設定
        echo "$query" > "/tmp/websearch_fallback_$USER"
        
        echo "Gemini quota exceeded. WebSearch fallback activated for: $query" >&2
        echo "Please use WebSearch tool directly for: $query" >&2
    fi
    exit 1
fi

# コマンドの終了コードを確認
if [ -f "$temp_file" ]; then
    if grep -q "status 429\|Quota exceeded\|rateLimitExceeded" "$temp_file"; then
        echo -e "\033[48;5;224m\033[38;5;160m ⚠️  Gemini quota exceeded \033[0m" >&2
        rm -f "$temp_file"
        exit 1
    elif [ -s "$temp_file" ]; then
        # 結果のサイズを取得
        result_size=$(wc -c < "$temp_file" 2>/dev/null || echo "0")
        result_lines=$(wc -l < "$temp_file" 2>/dev/null || echo "0")
        
        if [ -n "$search_query" ]; then
            echo -e "\033[48;5;225m\033[38;5;99m ✨ Search completed: \"$search_query\" ($result_size bytes, $result_lines lines) \033[0m" >&2
        else
            echo -e "\033[48;5;225m\033[38;5;99m ✨ Gemini search completed ($result_size bytes, $result_lines lines) \033[0m" >&2
        fi
        rm -f "$temp_file"
        exit 0
    else
        echo -e "\033[48;5;224m\033[38;5;160m ⚠️  Gemini search failed \033[0m" >&2
        rm -f "$temp_file"
        exit 1
    fi
else
    echo -e "\033[48;5;224m\033[38;5;160m ⚠️  Gemini execution error \033[0m" >&2
    exit 1
fi