# レーン: score — 診断だけ（書き換えない）

「この文章AIが書いた？」「AI臭さをスコアで出して」「どれくらいAIっぽいか判定して」と言われたときのレーン。**文書を書き換えない。**自然度スコア（0〜100、高いほど自然＝AI臭が薄い）と理由で返す。

## 最初に必ず読む

`references/diagnose.md`。スコアの算出式・バンド・出力形式の定義がそこにある。これを読まずに lint の findings を転記して返した時点で、診断モードの仕事になっていない。

## 深さの指定

- **quick（既定）** — lint のみ。30秒程度
- **full** — 構造レビュー・読みやすさレビュー込み（`polish-without-agy.md` の4を参照）
- **exp** — `scripts/semantic.py` の深層検出込み。初回は約1GBのモデルダウンロードを伴う

## 進め方

```
cd <このスキルのディレクトリ> && uv run scripts/lint.py --json <file>
```

ジャンルが明確なら `--genre essay|tech|business` を付ける。出力は `references/diagnose.md` の式に沿ってスコアに変換し、バンドと理由を添えて返す。

診断後にリライトを提案してよいが、**頼まれるまで直さない。**直してほしいと言われたら `polish.md` へ移る（agy を使わない場合は `polish-without-agy.md`）。
