#!/bin/bash
# 最小限のテストHook - Hook発火の確認のみ

LOG_FILE="/tmp/hook_test.log"

# 実行確認用ログ
echo "$(date): テストHook実行開始" >> "$LOG_FILE"

# 入力データの記録（デバッグ用）
INPUT=$(cat)
echo "$(date): 入力データ: $INPUT" >> "$LOG_FILE"

# 成功ログ
echo "$(date): テストHook実行完了" >> "$LOG_FILE"

# 音で実行確認（システムビープ）
echo -e "\a" 2>/dev/null

# 確実にファイルに記録
echo "Hook実行: $(date)" >> /tmp/hook_execution_test.txt

exit 0