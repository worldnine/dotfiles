#!/bin/bash
#
# Claude Code Statusline Handler
# ===============================
# Anthropic Usage API による利用率表示と
# コンテキスト使用率をリアルタイムで statusline に表示
#
# 表示レイアウト:
# 1行目: * Opus 4.6  ● 57.8K(29%)  58% ▓▓▓▓▓│░░░░ 6pm  5% ░│░░░░░░░░░ 3/8
# 2行目: [WT] project-name on git main +10 -5
#
# 使用方法:
# ~/.claude/settings.json に以下を設定:
#   "statusLine": {
#     "type": "command",
#     "command": "cat | bash /Users/nagata/.claude/statusline-handler.sh"
#   }
#
# テスト方法:
#   echo '{"model":{"display_name":"Opus 4.6"},"session_id":"test","cwd":"/tmp","context_window":{"used_percentage":29}}' | bash ~/.claude/statusline-handler.sh
#
# デバッグモード:
#   DEBUG_STATUSLINE=1 を設定すると詳細ログが出力される
#

USAGE_CACHE="/tmp/claude-statusline-usage.json"
USAGE_CACHE_TTL=60  # キャッシュ有効期間（秒）
CONTEXT_MAX_TOKENS=200000  # コンテキスト制限の概算値（トークン数表示の概算用）

# アイコン設定
setup_icons() {
    ICON_TERMINAL="*"
    ICON_TREE="[WT]"
    ICON_CONTEXT="●"
}

# カラー設定
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

# Usage API からデータ取得
# macOS Keychain から OAuth トークンを取得し、利用率エンドポイントを呼び出す
fetch_usage() {
    local creds token response
    creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || return 1
    token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken') || return 1
    [ -z "$token" ] || [ "$token" = "null" ] && return 1
    response=$(curl -s --max-time 3 "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Content-Type: application/json" 2>/dev/null) || return 1
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        return 1
    fi
    echo "$response" > "$USAGE_CACHE"
}

# キャッシュ付きUsageデータ取得（TTL超過時のみAPI再取得）
get_usage_data() {
    local now cache_mtime age
    now=$(date "+%s")
    cache_mtime=0
    if [ -f "$USAGE_CACHE" ]; then
        cache_mtime=$(stat -f "%m" "$USAGE_CACHE" 2>/dev/null || echo "0")
    fi
    age=$((now - cache_mtime))
    if [ "$age" -ge "$USAGE_CACHE_TTL" ]; then
        fetch_usage
    fi
    if [ -f "$USAGE_CACHE" ]; then
        cat "$USAGE_CACHE"
    fi
}

# 使用率に応じた色（ペーシングターゲット基準）
# $1: 使用率(0-100)  $2: ペーシングターゲット(0-100, 省略可)
# ≥80% → 赤、ペース超過かつ12%以上 → オレンジ、それ以外 → デフォルト
color_for_pct() {
    local pct=$1 target=${2:-}
    if [ "$pct" -ge 80 ]; then
        printf '%s' $'\033[91m'
    elif [ -n "$target" ] && [ "$pct" -gt "$target" ] && [ "$pct" -ge 12 ]; then
        printf '%s' $'\033[38;5;208m'
    else
        printf '%s' $'\033[39m'
    fi
}

# コンテキスト使用率に応じた色（既存ロジック維持: <50% デフォルト、50-80% オレンジ、>80% 赤）
get_context_color() {
    local pct=$1
    if [ "$pct" -ge 80 ]; then
        echo "$COLOR_RED"
    elif [ "$pct" -ge 50 ]; then
        echo "$COLOR_ORANGE"
    else
        echo "$COLOR_DEFAULT"
    fi
}

# プログレスバー生成（10文字幅、細線スタイル ━/─ + ペーシングマーカー│）
# $1: 使用率(0-100)  $2: ペーシングターゲット(0-100, 省略可)  $3: ANSIカラー
make_bar() {
    local pct=$1 target=${2:-} color=${3:-} width=10
    local filled=$((pct * width / 100))
    [ "$filled" -gt "$width" ] && filled=$width
    local target_pos=-1
    if [ -n "$target" ] && [ "$target" -ge 0 ] 2>/dev/null && [ "$target" -le 100 ]; then
        target_pos=$((target * width / 100))
        [ "$target_pos" -ge "$width" ] && target_pos=$((width - 1))
    fi
    local MARKER_COLOR=$'\033[38;5;174m'
    local DIM=$'\033[2m'
    local RESET=$'\033[0m'
    local bar=""
    for ((i=0; i<width; i++)); do
        if [ "$i" -eq "$target_pos" ]; then
            bar="${bar}${MARKER_COLOR}│${RESET}${color}"
        elif [ "$i" -lt "$filled" ]; then
            bar="${bar}━"
        else
            bar="${bar}${DIM}─${RESET}${color}"
        fi
    done
    printf "%s" "$bar"
}

# ペーシングターゲット計算
# ウィンドウ内の経過時間の割合を0-100で返す
# $1: resets_at (UTC ISO 8601, 例: "2026-02-08T04:59:59.000000+00:00")
# $2: ウィンドウ秒数 (5hr=18000, 7d=604800)
calc_pacing_target() {
    local resets_at="$1"
    local window_secs="$2"
    [ -z "$resets_at" ] || [ "$resets_at" = "null" ] && return
    local trimmed="${resets_at%%.*}"
    local reset_epoch now_epoch elapsed
    reset_epoch=$(date -ujf "%Y-%m-%dT%H:%M:%S" "$trimmed" "+%s" 2>/dev/null) || return
    now_epoch=$(date "+%s")
    elapsed=$((window_secs - (reset_epoch - now_epoch)))
    [ "$elapsed" -lt 0 ] && elapsed=0
    [ "$elapsed" -gt "$window_secs" ] && elapsed=$window_secs
    echo $((elapsed * 100 / window_secs))
}

# リセットまでの残り時間をフォーマット
# 1日以上 → "4d"、1時間以上 → "3h"、1時間未満 → "42m"
format_remaining() {
    local resets_at="$1"
    local trimmed="${resets_at%%.*}"
    local reset_epoch now_epoch remaining
    reset_epoch=$(date -ujf "%Y-%m-%dT%H:%M:%S" "$trimmed" "+%s" 2>/dev/null) || return
    now_epoch=$(date "+%s")
    remaining=$((reset_epoch - now_epoch))
    [ "$remaining" -lt 0 ] && remaining=0
    if [ "$remaining" -ge 86400 ]; then
        echo "$((remaining / 86400))d"
    elif [ "$remaining" -ge 3600 ]; then
        echo "$((remaining / 3600))h"
    else
        echo "$((remaining / 60))m"
    fi
}

# メイン処理
main() {
    setup_icons
    setup_colors

    input=$(cat)

    # デバッグモード
    if [ "${DEBUG_STATUSLINE:-}" = "1" ]; then
        echo "=== INPUT JSON ===" >&2
        echo "$input" | jq '.' >&2 2>/dev/null || echo "$input" >&2
        echo "==================" >&2
    fi

    # 入力JSONからデータ取得
    model_display=$(echo "$input" | jq -r '.model.display_name // "Unknown"' 2>/dev/null)
    cwd=$(echo "$input" | jq -r '.cwd' 2>/dev/null)
    project=$(echo "$input" | jq -r '.workspace.current_dir' 2>/dev/null | xargs basename 2>/dev/null)

    # コンテキスト使用率（Claude Code の JSON から直接取得）
    context_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null)
    context_tokens=$(echo "$input" | jq -r '.context_window.used // 0' 2>/dev/null)

    # トークン数が取得できない場合はパーセンテージから概算
    if [ "$context_tokens" -le 0 ] 2>/dev/null && [ "$context_pct" -gt 0 ] 2>/dev/null; then
        context_tokens=$((context_pct * CONTEXT_MAX_TOKENS / 100))
    fi

    # Git情報
    branch=""
    if [ -n "$cwd" ]; then
        branch=$(cd "$cwd" 2>/dev/null && git branch --show-current 2>/dev/null)
    fi

    # Worktree検出
    is_worktree=""
    if [ -n "$branch" ] && [ -n "$cwd" ]; then
        git_common_dir=$(cd "$cwd" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)
        git_dir=$(cd "$cwd" 2>/dev/null && git rev-parse --git-dir 2>/dev/null)
        if [ -n "$git_common_dir" ] && [ -n "$git_dir" ] && [ "$git_common_dir" != "$git_dir" ]; then
            is_worktree="$ICON_TREE"
        fi
    fi

    # Git差分統計
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

    # === 1行目: モデル名 + コンテキスト + Usage ===
    line1=$(printf '%s%s %s%s' "$COLOR_ORANGE" "$ICON_TERMINAL" "$model_display" "$COLOR_DEFAULT")

    # コンテキスト使用率表示
    if [ "$context_pct" -gt 0 ] 2>/dev/null; then
        token_display=""
        if [ "$context_tokens" -gt 0 ] 2>/dev/null; then
            if [ "$context_tokens" -ge 1000000 ]; then
                token_display=$(echo "$context_tokens" | awk '{printf "%.1fM", $1/1000000}')
            elif [ "$context_tokens" -ge 1000 ]; then
                token_display=$(echo "$context_tokens" | awk '{printf "%.1fK", $1/1000}')
            else
                token_display="$context_tokens"
            fi
        fi

        ctx_color=$(get_context_color "$context_pct")
        if [ -n "$token_display" ]; then
            line1="${line1}  ${ctx_color}${ICON_CONTEXT} ${token_display}(${context_pct}%)${COLOR_DEFAULT}"
        else
            line1="${line1}  ${ctx_color}${ICON_CONTEXT} ${context_pct}%${COLOR_DEFAULT}"
        fi
    fi

    # Usage APIデータ取得・表示
    usage_data=$(get_usage_data)
    if [ -n "$usage_data" ]; then
        # 5時間枠
        five_hr_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' 2>/dev/null | awk '{printf "%d", $1}')
        five_hr_reset=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)

        if [ -n "$five_hr_pct" ] && [ "$five_hr_pct" != "null" ]; then
            five_target=$(calc_pacing_target "$five_hr_reset" 18000)
            five_color=$(color_for_pct "$five_hr_pct" "$five_target")
            five_bar=$(make_bar "$five_hr_pct" "$five_target" "$five_color")
            five_reset_str=""
            if [ -n "$five_hr_reset" ] && [ "$five_hr_reset" != "null" ]; then
                five_reset_str=$(format_remaining "$five_hr_reset")
            fi
            if [ -n "$five_reset_str" ]; then
                line1="${line1}  ${five_color}${five_hr_pct}% ${five_bar}${COLOR_DEFAULT} ${five_reset_str}"
            else
                line1="${line1}  ${five_color}${five_hr_pct}% ${five_bar}${COLOR_DEFAULT}"
            fi
        fi

        # 7日枠
        seven_day_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' 2>/dev/null | awk '{printf "%d", $1}')
        seven_day_reset=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)

        if [ -n "$seven_day_pct" ] && [ "$seven_day_pct" != "null" ]; then
            seven_target=$(calc_pacing_target "$seven_day_reset" 604800)
            seven_color=$(color_for_pct "$seven_day_pct" "$seven_target")
            seven_bar=$(make_bar "$seven_day_pct" "$seven_target" "$seven_color")
            seven_reset_str=""
            if [ -n "$seven_day_reset" ] && [ "$seven_day_reset" != "null" ]; then
                seven_reset_str=$(format_remaining "$seven_day_reset")
            fi
            if [ -n "$seven_reset_str" ]; then
                line1="${line1}  ${seven_color}${seven_day_pct}% ${seven_bar}${COLOR_DEFAULT} ${seven_reset_str}"
            else
                line1="${line1}  ${seven_color}${seven_day_pct}% ${seven_bar}${COLOR_DEFAULT}"
            fi
        fi
    fi

    # 1行目出力
    printf "%s\n" "$line1"

    # === 2行目: Worktree + Git情報 ===
    if [ -n "$is_worktree" ]; then
        printf '%s%s%s ' "$COLOR_BRIGHT_GREEN" "$is_worktree" "$COLOR_DEFAULT"
    fi

    if [ -n "$branch" ] && [ -n "$project" ]; then
        printf '%s%s%s on %sgit %s%s%s' "$COLOR_BLUE" "$project" "$COLOR_DEFAULT" "$COLOR_PINK" "$branch" "$COLOR_DEFAULT" "$git_stats"
    elif [ -n "$branch" ]; then
        printf '%sgit %s%s%s' "$COLOR_PINK" "$branch" "$COLOR_DEFAULT" "$git_stats"
    elif [ -n "$project" ]; then
        printf '%s%s%s' "$COLOR_BLUE" "$project" "$COLOR_DEFAULT"
    fi
}

# スクリプトを実行
main "$@"
