#!/bin/bash

# WebSearchクエリをjqで抽出
query=$(jq -r '.tool_input.query')

# geminiの出力を一時ファイルに保存
temp_file="/tmp/gemini_output_$$"

# geminiを実行し、出力をリアルタイム監視（タイムアウトなし）
gemini -p "WebSearch:${query}" 2>&1 | tee "$temp_file" | while IFS= read -r line; do
    # 429エラーまたはクォータ制限を検出したら即座に終了
    if echo "$line" | grep -q "status 429\|Quota exceeded\|rateLimitExceeded"; then
        # geminiプロセスをkill
        pkill -f "gemini.*WebSearch" 2>/dev/null
        # JSON形式でWebSearchの実行を承認
        echo '{"decision": "approve", "reason": "Gemini quota exceeded, falling back to WebSearch"}'
        rm -f "$temp_file"
        exit 0
    fi
done

# 正常終了時：従来方式でgeminiの結果をClaudeに渡す
if [ -f "$temp_file" ] && [ -s "$temp_file" ] && ! grep -q "status 429\|Quota exceeded\|rateLimitExceeded" "$temp_file"; then
    # 正常な結果がある場合：stderrに出力してexit 2でブロック
    echo -e "\033[48;2;135;206;250m\033[30m 🔍 Searched with Gemini \033[0m" >&2
    cat "$temp_file" >&2
    rm -f "$temp_file"
    exit 2  # WebSearchをブロック + stderrをClaudeに渡す
else
    # その他の場合（タイムアウト、エラーなど）：WebSearchにフォールバック
    echo '{"decision": "approve", "reason": "Gemini request failed, falling back to WebSearch"}'
    rm -f "$temp_file"
    exit 0
fi