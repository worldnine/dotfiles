#!/bin/bash
#
# Claude Code Statusline Handler
# ===============================
# Claude Codeのstatuslineに表示する情報をカスタマイズするスクリプト
# ccusage (https://github.com/ryoppippi/ccusage) と連携して
# セッショントークン数、コンテキスト使用率、コスト情報などを表示
#
# 使用方法:
# ----------
# 1. ~/.claude/settings.json に以下を設定:
#    "statusLine": {
#      "type": "command",
#      "command": "cat | bash /Users/nagata/.claude/statusline-handler.sh"
#    }
#
# 2. ccusageはbunxで自動的に取得されるため、事前インストール不要
#
# テスト方法:
# ----------
# 実際の表示確認には bunx ccusage statusline を使用すると便利:
#   echo '{"model":{"id":"claude-sonnet-4","display_name":"Sonnet 4"},...}' | bunx ccusage statusline
#
# 本スクリプトのテスト:
#   echo '{"model":{"id":"claude-sonnet-4","display_name":"Sonnet 4"},...}' | bash statusline-handler.sh
#
# デバッグモード:
#   DEBUG_STATUSLINE=1 を設定すると詳細ログが出力される
#
# 実装の特徴:
# ----------
# - ccusage session --id APIで正確なセッションデータを取得
# - コンテキスト使用率を194K制限で計算（オートコンパクト仕様準拠）
# - 色分け: <50% 緑、50-80% 黄、>80% 赤
# - COLOR_DEFAULT (\033[39m) を使用してstatusline環境の文字色を保持
#

DEBUG_CCUSAGE=0

# アイコン設定
setup_icons() {
    ICON_TERMINAL="*"      # モデル表示用
    ICON_FIRE="▲"          # 時間あたりコスト表示用
    ICON_TREE="[WT]"       # Worktree表示用
    ICON_CONTEXT="●"       # コンテキスト使用率表示用
    ICON_COST="■"          # 積算コスト表示用
}

# 警告閾値設定
setup_warning_thresholds() {
    # 5時間ブロック上限設定（USD）
    # プラン別目安:
    # - Pro ($20/月): $20-30推奨 (10-40プロンプト/5h)
    # - Max 5x ($100/月): $50-100推奨 (50-200プロンプト/5h)  
    # - Max 20x ($200/月): $150-300推奨 (200-800プロンプト/5h)
    # - API: 個人予算に応じて設定
    BURN_RATE_LIMIT_USD=50.00
    
    # 積算コスト警告閾値（現在使用額/上限）
    # 意味: 既に使った確定額の危険度（変更不可能な現実）
    # 対応: 残り予算での作業計画
    CURRENT_COST_CAUTION_THRESHOLD=0.75    # 75%で注意「残りわずか」
    CURRENT_COST_WARNING_THRESHOLD=0.90    # 90%で警告「ほぼ上限」
    
    # バーンレート警告閾値（予測追加額/残り予算）
    # 意味: このペースが続くと危険か（調整可能な未来）
    # 対応: 作業方法の調整、軽量タスクへの切り替え
    BURN_RATE_CAUTION_THRESHOLD=0.75       # 残り予算の75%消費予測で注意
    BURN_RATE_WARNING_THRESHOLD=1.00       # 残り予算の100%消費予測で警告

    # コンテキスト使用率警告閾値（現在使用量/制限）
    # 意味: メモリ使用量の危険度（技術的制限）
    # 対応: /compact実行、セッション分割検討
    CONTEXT_CAUTION_THRESHOLD=0.50         # 50%で注意「半分使用」
    CONTEXT_WARNING_THRESHOLD=0.80         # 80%で警告「オートコンパクト間近」
    
    # コンテキスト制限値設定（トークン数）
    # Claude Code仕様: 80%でオートコンパクト発動
    # 実測: 155.1Kで80%到達時「Context left until auto-compact: 0%」
    # 逆算: 155.1K ÷ 0.8 = 193.875K → 真の制限は約194K
    CONTEXT_MAX_TOKENS=193604               # オートコンパクト仕様に基づく制限値（単位調整）
}

# カラー設定関数
setup_colors() {
    if [ -n "$NO_COLOR" ] || [ "$USE_COLORS" = "false" ]; then
        COLOR_RESET=""
        COLOR_DEFAULT=""
        COLOR_BLUE=""
        COLOR_PINK=""
        COLOR_GREEN=""
        COLOR_RED=""
        COLOR_BRIGHT_GREEN=""
        COLOR_ORANGE=""
    else
        COLOR_RESET=$'\033[0m'
        COLOR_DEFAULT=$'\033[39m'  # 前景色のみデフォルトに戻す（statusline環境用）
        COLOR_BLUE=$'\033[34m'
        COLOR_PINK=$'\033[95m'
        COLOR_GREEN=$'\033[92m'
        COLOR_RED=$'\033[91m'
        COLOR_BRIGHT_GREEN=$'\033[32m'
        COLOR_ORANGE=$'\033[38;5;208m'
    fi
}



# アクティブブロック情報を取得する関数
get_active_block_data() {
    echo '{}' | bunx ccusage blocks --active --json 2>/dev/null
}

# 現在のセッション情報を取得する関数
# ccusage session --id APIを使用して特定セッションの詳細データを取得
# 戻り値: JSON形式のセッションデータ（totalTokens, entries配列など）
get_current_session_data() {
    local session_id="$1"
    if [ -n "$session_id" ] && [ "$session_id" != "null" ]; then
        # ccusage session --idで特定セッションの詳細データを取得
        # 注意: このAPIは大量のデータを返すため、処理に時間がかかる場合がある
        bunx ccusage session --id "$session_id" --json 2>/dev/null
    fi
}

# セッションデータから現在のコンテキストサイズを算出する関数
# アルゴリズム: 最新エントリのcacheReadTokens + cacheCreationTokens
# これはccusage statuslineの表示値とほぼ一致する（誤差1-2%程度）
get_session_context_tokens() {
    local session_data="$1"
    if [ -n "$session_data" ] && [ "$session_data" != "null" ]; then
        # 最新エントリ（配列の最後）から現在のコンテキストサイズを取得
        # cacheReadTokens: キャッシュから読み込まれたトークン数
        # cacheCreationTokens: 新規作成されたキャッシュトークン数
        local latest_cache_read=$(echo "$session_data" | jq -r '.entries[-1].cacheReadTokens // 0' 2>/dev/null)
        local latest_cache_creation=$(echo "$session_data" | jq -r '.entries[-1].cacheCreationTokens // 0' 2>/dev/null)
        
        if [ -n "$latest_cache_read" ] && [ -n "$latest_cache_creation" ]; then
            echo $((latest_cache_read + latest_cache_creation))
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# transcriptファイルからトークン情報を取得する関数（フォールバック用）
get_transcript_tokens() {
    local transcript_path="$1"
    if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
        # cache_read_input_tokensの最新値を使用（フォールバック）
        local cache_read_tokens=$(grep '"cache_read_input_tokens":' "$transcript_path" | tail -1 | grep -oE '"cache_read_input_tokens":([0-9]+)' | grep -oE '[0-9]+')
        
        if [ -n "$cache_read_tokens" ] && [ "$cache_read_tokens" -gt 0 ]; then
            echo "$cache_read_tokens"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# コンテキスト使用率を計算する関数
# 制限値: Claude Code仕様（80%でオートコンパクト発動）に基づく
# 実測: 155.1Kで80%到達 → 真の制限は約194K
calculate_context_percentage() {
    local session_tokens="$1"
    # オートコンパクト仕様に基づく実測制限値を使用
    local max_tokens="$CONTEXT_MAX_TOKENS"
    
    if [ -n "$session_tokens" ] && [ "$session_tokens" -gt 0 ] && [ -n "$max_tokens" ] && [ "$max_tokens" -gt 0 ]; then
        # より正確な計算のためbcを使用（四捨五入）
        local percentage=$(echo "scale=0; ($session_tokens * 100 / $max_tokens) + 0.5" | bc -l 2>/dev/null || echo "0")
        echo "$percentage"
    else
        echo "0"
    fi
}

# コンテキスト使用率に応じた色を取得する関数
# 設定値に基づく色分け（パーセント vs 比率の比較）
get_context_percentage_color() {
    local percentage="$1"
    
    # パーセント（47）を比率（0.47）に変換して比較
    local percentage_ratio=$(echo "scale=6; $percentage / 100" | bc -l 2>/dev/null || echo "0")
    
    # bc による浮動小数点比較（1 = true, 0 = false）
    local is_warning=$(echo "$percentage_ratio >= $CONTEXT_WARNING_THRESHOLD" | bc -l 2>/dev/null || echo "0")
    local is_caution=$(echo "$percentage_ratio >= $CONTEXT_CAUTION_THRESHOLD" | bc -l 2>/dev/null || echo "0")
    
    if [ "$is_warning" = "1" ]; then
        echo "$COLOR_RED"
    elif [ "$is_caution" = "1" ]; then
        echo "$COLOR_ORANGE"
    else
        echo "$COLOR_DEFAULT"
    fi
}

# 積算コスト（実測値）の色を取得する関数
# 判定基準: 現在使用額 / 上限
get_current_cost_color() {
    local current_cost="$1"
    local limit="$2"
    
    # 引数チェック
    if [ -z "$current_cost" ] || [ -z "$limit" ] || [ "$limit" = "0" ]; then
        echo "$COLOR_DEFAULT"
        return
    fi
    
    # 現在使用率 = 現在コスト / 上限
    local current_ratio=$(echo "scale=6; $current_cost / $limit" | bc -l 2>/dev/null || echo "0")
    
    # bc による浮動小数点比較（1 = true, 0 = false）
    local is_warning=$(echo "$current_ratio >= $CURRENT_COST_WARNING_THRESHOLD" | bc -l 2>/dev/null || echo "0")
    local is_caution=$(echo "$current_ratio >= $CURRENT_COST_CAUTION_THRESHOLD" | bc -l 2>/dev/null || echo "0")
    
    if [ "$is_warning" = "1" ]; then
        echo "$COLOR_RED"
    elif [ "$is_caution" = "1" ]; then
        echo "$COLOR_ORANGE"
    else
        echo "$COLOR_DEFAULT"
    fi
}

# バーンレート（予測値）の色を取得する関数
# 判定基準: 予測追加コスト / 残り予算
get_burn_rate_color() {
    local current_cost="$1"
    local burn_rate_per_hour="$2"
    local remaining_minutes="$3"
    local limit="$4"
    
    # 引数チェック
    if [ -z "$current_cost" ] || [ -z "$burn_rate_per_hour" ] || [ -z "$remaining_minutes" ] || [ -z "$limit" ]; then
        echo "$COLOR_DEFAULT"
        return
    fi
    
    # 残り予算 = 上限 - 現在コスト
    local remaining_budget=$(echo "scale=2; $limit - $current_cost" | bc -l 2>/dev/null || echo "0")
    
    # 残り予算がマイナスまたは0の場合はデフォルト色
    if [ $(echo "$remaining_budget <= 0" | bc -l 2>/dev/null || echo "1") = "1" ]; then
        echo "$COLOR_DEFAULT"
        return
    fi
    
    # 残り時間を時間単位に変換
    local remaining_hours=$(echo "scale=6; $remaining_minutes / 60" | bc -l 2>/dev/null || echo "0")
    
    # 予測追加コスト = バーンレート × 残り時間
    local predicted_additional=$(echo "scale=2; $burn_rate_per_hour * $remaining_hours" | bc -l 2>/dev/null || echo "0")
    
    # バーンレート比率 = 予測追加コスト / 残り予算
    local burn_ratio=$(echo "scale=6; $predicted_additional / $remaining_budget" | bc -l 2>/dev/null || echo "0")
    
    # bc による浮動小数点比較（1 = true, 0 = false）
    local is_warning=$(echo "$burn_ratio >= $BURN_RATE_WARNING_THRESHOLD" | bc -l 2>/dev/null || echo "0")
    local is_caution=$(echo "$burn_ratio >= $BURN_RATE_CAUTION_THRESHOLD" | bc -l 2>/dev/null || echo "0")
    
    if [ "$is_warning" = "1" ]; then
        echo "$COLOR_RED"
    elif [ "$is_caution" = "1" ]; then
        echo "$COLOR_ORANGE"
    else
        echo "$COLOR_DEFAULT"
    fi
}

# メイン処理
main() {
    setup_icons
    setup_colors
    setup_warning_thresholds
    
    input=$(cat)
    
    # デバッグモード: 実際の入力JSONをログ出力
    if [ "${DEBUG_STATUSLINE:-}" = "1" ]; then
        echo "=== ACTUAL INPUT JSON ===" >&2
        echo "$input" | jq '.' >&2 2>/dev/null || echo "$input" >&2
        echo "========================" >&2
    fi
    
    # 入力JSONから直接モデル名とセッションIDを取得
    model_display=$(echo "$input" | jq -r '.model.display_name // "Unknown"' 2>/dev/null)
    session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
    transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
    
    # デバッグ出力
    if [ "${DEBUG_STATUSLINE:-}" = "1" ]; then
        echo "DEBUG: model_display=[$model_display]" >&2
        echo "DEBUG: session_id=[$session_id]" >&2
        echo "DEBUG: transcript_path=[$transcript_path]" >&2
    fi
    
    
    # 現在のセッション情報を取得
    session_data=""
    session_data=$(get_current_session_data "$session_id")
    
    # デバッグ出力
    if [ "${DEBUG_STATUSLINE:-}" = "1" ]; then
        echo "DEBUG: session_data length: ${#session_data}" >&2
        if [ -n "$session_data" ]; then
            echo "DEBUG: session_data found!" >&2
        else
            echo "DEBUG: session_data is empty - checking available sessions..." >&2
            echo '{}' | bunx ccusage session --json 2>/dev/null | jq -r '.sessions[0:3] | .[] | .sessionId' 2>/dev/null | head -3 >&2
        fi
    fi
    
    
    # アクティブブロック情報を取得（バーンレート、残り時間など）
    active_block_data=""
    active_block_data=$(get_active_block_data)
    
    cwd=$(echo "$input" | jq -r '.cwd' 2>/dev/null)
    branch=$(cd "$cwd" 2>/dev/null && git branch --show-current 2>/dev/null)
    project=$(echo "$input" | jq -r '.workspace.current_dir' 2>/dev/null | xargs basename 2>/dev/null)

    # Worktreeかどうかを検出
    is_worktree=""
    if [ -n "$branch" ] && [ -n "$cwd" ]; then
        git_common_dir=$(cd "$cwd" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)
        git_dir=$(cd "$cwd" 2>/dev/null && git rev-parse --git-dir 2>/dev/null)
        if [ -n "$git_common_dir" ] && [ -n "$git_dir" ] && [ "$git_common_dir" != "$git_dir" ]; then
            is_worktree="$ICON_TREE"
        fi
    fi

    # Git差分統計を取得（ステージングされていない変更）
    git_stats=""
    if [ -n "$branch" ] && [ -n "$cwd" ]; then
        stats=$(cd "$cwd" 2>/dev/null && git diff --shortstat 2>/dev/null)
        if [ -n "$stats" ]; then
            insertions=$(echo "$stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
            deletions=$(echo "$stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
            if [ "$insertions" != "0" ] || [ "$deletions" != "0" ]; then
                git_stats=$(printf ' %s+%s%s %s-%s%s' "$COLOR_GREEN" "$insertions" "$COLOR_RESET" "$COLOR_RED" "$deletions" "$COLOR_RESET")
            fi
        fi
    fi

    # セッション情報とccusage出力を組み合わせて表示情報を構築
    parsed_output=""
    
    # アクティブブロックからバーンレートと時間情報を取得
    block_price=""
    block_time=""
    hourly_rate=""
    token_info=""
    if [ -n "$active_block_data" ]; then
        # JSONからバーンレート情報を抽出
        burn_rate_per_hour=$(echo "$active_block_data" | jq -r '.blocks[0].burnRate.costPerHour // empty' 2>/dev/null)
        remaining_minutes=$(echo "$active_block_data" | jq -r '.blocks[0].projection.remainingMinutes // empty' 2>/dev/null)
        total_block_cost=$(echo "$active_block_data" | jq -r '.blocks[0].costUSD // empty' 2>/dev/null)
        
        # 独立警告計算と色分け
        current_cost_color="$COLOR_DEFAULT"
        burn_rate_color="$COLOR_DEFAULT"
        
        # 積算コスト（実測値）の色判定
        if [ -n "$total_block_cost" ] && [ "$total_block_cost" != "null" ]; then
            current_cost_color=$(get_current_cost_color "$total_block_cost" "$BURN_RATE_LIMIT_USD")
        fi
        
        # バーンレート（予測値）の色判定
        if [ -n "$burn_rate_per_hour" ] && [ "$burn_rate_per_hour" != "null" ] && \
           [ -n "$total_block_cost" ] && [ "$total_block_cost" != "null" ] && \
           [ -n "$remaining_minutes" ] && [ "$remaining_minutes" != "null" ]; then
            burn_rate_color=$(get_burn_rate_color "$total_block_cost" "$burn_rate_per_hour" "$remaining_minutes" "$BURN_RATE_LIMIT_USD")
        fi
        
        # デバッグ出力
        if [ "${DEBUG_STATUSLINE:-}" = "1" ]; then
            current_ratio=$(echo "scale=2; $total_block_cost / $BURN_RATE_LIMIT_USD * 100" | bc -l 2>/dev/null || echo "0")
            remaining_budget=$(echo "scale=2; $BURN_RATE_LIMIT_USD - $total_block_cost" | bc -l 2>/dev/null || echo "0")
            predicted_additional=$(echo "scale=2; $burn_rate_per_hour * $remaining_minutes / 60" | bc -l 2>/dev/null || echo "0")
            burn_ratio=$(echo "scale=2; $predicted_additional / $remaining_budget * 100" | bc -l 2>/dev/null || echo "0")
            echo "DEBUG: current cost - $total_block_cost/${BURN_RATE_LIMIT_USD} (${current_ratio}%), burn rate - +$predicted_additional/${remaining_budget} (${burn_ratio}%)" >&2
        fi
        
        # フォーマット調整（アイコン含む独立色付き）
        if [ -n "$burn_rate_per_hour" ] && [ "$burn_rate_per_hour" != "null" ]; then
            hourly_rate=$(printf "%s%s $%.2f/h%s" "$burn_rate_color" "$ICON_FIRE" "$burn_rate_per_hour" "$COLOR_DEFAULT")
        fi
        
        if [ -n "$total_block_cost" ] && [ "$total_block_cost" != "null" ]; then
            block_price=$(printf "%s%s $%.2f%s" "$current_cost_color" "$ICON_COST" "$total_block_cost" "$COLOR_DEFAULT")
        fi
        
        if [ -n "$remaining_minutes" ] && [ "$remaining_minutes" != "null" ]; then
            hours=$((remaining_minutes / 60))
            mins=$((remaining_minutes % 60))
            if [ "$hours" -gt 0 ]; then
                block_time="${hours}h${mins}m"
            else
                block_time="${mins}m"
            fi
        fi
        
    fi
    
    # 現在のセッション（スレッド）のトークン情報とコスト情報を取得
    # 処理の流れ:
    # 1. ccusage session --id でセッションデータ取得を試行
    # 2. 成功した場合、最新エントリからコンテキストサイズとセッションコストを算出
    # 3. 失敗した場合、transcriptファイルから直接読み取り（フォールバック）
    token_info=""
    session_tokens=0
    session_cost=""
    
    if [ -n "$session_data" ]; then
        # ccusage session --idからコンテキストサイズを算出
        session_tokens=$(get_session_context_tokens "$session_data")
        
        # ccusage session --idからセッションコストを取得
        session_cost=$(echo "$session_data" | jq -r '.totalCost // empty' 2>/dev/null)
        
        # デバッグ出力: ccusageから取得したトークン数とコスト
        if [ "${DEBUG_STATUSLINE:-}" = "1" ]; then
            echo "DEBUG: session_tokens from ccusage=[$session_tokens]" >&2
            echo "DEBUG: session_cost from ccusage=[$session_cost]" >&2
        fi
    fi
    
    # ccusageデータが取得できない場合のフォールバック
    # 新しいセッションはccusageにまだ登録されていない可能性がある
    if [ "$session_tokens" -eq 0 ] && [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
        session_tokens=$(get_transcript_tokens "$transcript_path")
        
        # デバッグ出力: transcriptから取得したトークン数
        if [ "${DEBUG_STATUSLINE:-}" = "1" ]; then
            echo "DEBUG: session_tokens from transcript=[$session_tokens]" >&2
        fi
    fi
    
    # トークン情報を表示用にフォーマット
    if [ -n "$session_tokens" ] && [ "$session_tokens" -gt 0 ]; then
        # セッショントークン数を適切な単位で表示
        if [ "$session_tokens" -ge 1000000 ]; then
            session_display=$(echo "$session_tokens" | awk '{printf "%.1fM", $1/1000000}')
        elif [ "$session_tokens" -ge 1000 ]; then
            session_display=$(echo "$session_tokens" | awk '{printf "%.1fK", $1/1000}')
        else
            session_display="$session_tokens"
        fi
        
        # コンテキスト使用率を計算
        context_percentage=$(calculate_context_percentage "$session_tokens")
        if [ -n "$context_percentage" ]; then
            percentage_color=$(get_context_percentage_color "$context_percentage")
            # アイコン含む全体を色変更（サークル、スペース、トークン数、パーセンテージ）
            # COLOR_DEFAULT (\033[39m) を使用してstatusline環境の文字色を保持
            token_info="${percentage_color}${ICON_CONTEXT} ${session_display}(${context_percentage}%)${COLOR_DEFAULT}"
        else
            token_info="${session_display}"
        fi
        
        # デバッグ出力
        if [ "${DEBUG_STATUSLINE:-}" = "1" ]; then
            echo "DEBUG: final token_info=[$token_info]" >&2
        fi
    fi
        
        
    # 元のフォーマットを維持: * Model tokens $price / time ! $/h
    # 注意: ブロックコストのみ修正（projection.totalCost → costUSD）
    # 今日の統計情報は削除（ユーザー要求により）
    parsed_output=$(printf '%s%s %s%s' "$COLOR_ORANGE" "$ICON_TERMINAL" "$model_display" "$COLOR_DEFAULT")
    
    # トークン情報を追加
    if [ -n "$token_info" ]; then
        parsed_output=$(printf '%s  %s' "$parsed_output" "$token_info")
    fi
    
    if [ -n "$block_price" ] && [ -n "$block_time" ]; then
        if [ -n "$hourly_rate" ]; then
            # スペース配置: $parsed_output + [2スペース] + $block_price + [スペース/スペース] + $block_time + [2スペース] + $hourly_rate
            parsed_output=$(printf '%s  %s / %s  %s' "$parsed_output" "$block_price" "$block_time" "$hourly_rate")
        else
            # バーンレートがない場合は価格と時間のみ表示
            parsed_output=$(printf '%s  %s / %s' "$parsed_output" "$block_price" "$block_time")
        fi
    fi
    

    # 1行目: ccusage情報
    if [ -n "$parsed_output" ]; then
        printf "%s\n" "$parsed_output"
    fi

    # 2行目: プロジェクトとGit情報
    if [ -n "$is_worktree" ]; then
        # Worktreeインジケータを表示
        printf '%s%s%s ' "$COLOR_BRIGHT_GREEN" "$is_worktree" "$COLOR_DEFAULT"
    fi

    if [ -n "$branch" ] && [ -n "$project" ]; then
        # Starship形式: project on git branch (+追加 -削除)
        printf '%s%s%s on %sgit %s%s%s' "$COLOR_BLUE" "$project" "$COLOR_DEFAULT" "$COLOR_PINK" "$branch" "$COLOR_DEFAULT" "$git_stats"
    elif [ -n "$branch" ]; then
        printf '%sgit %s%s%s' "$COLOR_PINK" "$branch" "$COLOR_DEFAULT" "$git_stats"
    elif [ -n "$project" ]; then
        printf '%s%s%s' "$COLOR_BLUE" "$project" "$COLOR_DEFAULT"
    fi
    
    # ccusage比較用デバッグ出力
    if [ "${DEBUG_CCUSAGE:-}" = "1" ]; then
        printf "\n"
        ccusage_output=$(echo "$input" | bunx ccusage statusline 2>/dev/null || echo "N/A")
        printf '🧠 ccusage: %s' "$ccusage_output"
    fi
}

# スクリプトを実行
main "$@"