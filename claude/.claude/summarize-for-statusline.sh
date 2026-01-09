#!/bin/bash
# ステータスラインに表示するため、一時ファイルを読み込み、Gemini APIで要約する

# APIキーを環境変数から読み込む (事前に export GOOGLE_API_KEY="..." を設定)
API_KEY="${GOOGLE_API_KEY}"

# 一時ファイルのパス
TMP_FILE="/tmp/claude_tweet_source.txt"

if [ -z "$API_KEY" ];
  then
  echo "🔑 Google API Key not set"
  exit 1
fi

if [ ! -s "$TMP_FILE" ];
  then
  # ファイルが存在しない、または空の場合はデフォルトメッセージを表示
  echo "🤖 Ready for next tweet..."
  exit 0
fi

# ファイルから対話履歴を読み込む
HISTORY_TEXT=$(cat "$TMP_FILE")

# jqを使って安全にJSONペイロードを作成
JSON_PAYLOAD=$(jq -n --arg history "$HISTORY_TEXT" '{
  "contents": [{
    "parts": [{
      "text": ("以下の対話内容を、Claudeがまるで自分の考えであるかのようにX（旧Twitter）へ投稿する想定で、簡潔でウィットに富んだツイートを1つだけ生成してください。生成するのはツイート本文のみで、解説は不要です。\n\n---\n" + $history + "\n---")
    }]
  }],
  "generationConfig": {
    "maxOutputTokens": 60
  }
}')

# curlでGemini APIを呼び出し、jqで結果をパース
SUMMARY=$(curl -s -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${API_KEY}" \
     -H "Content-Type: application/json" \
     -d "$JSON_PAYLOAD" \
     | jq -r '.candidates[0].content.parts[0].text // "..."' | tr -d '\n' )

# 最終的な出力をステータスライン用に整形
echo "🐦 ${SUMMARY}"
