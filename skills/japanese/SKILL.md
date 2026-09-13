---
name: japanese
description: 日本語の文章を書く・直す・推敲するスキル。議事録（文字起こしからの議事録化を含む）、調査レポート・分析レポート、社内ガイド・マニュアル、リサーチメモ・ディスカッションペーパー・企画書・提案書・報告書・メール、note・ブログ・エッセイ、スライド構成案の作成と推敲に使う。「AIっぽい」「AI臭い」「機械翻訳っぽい」「不自然」「もっと自然な日本語に」「人間っぽくして」「単調」「読みにくい」「語順がおかしい」「一文が長い」「読点の位置がおかしい」といった指摘、リライト・推敲・校正の依頼、ゼロからの執筆、AI臭さの診断・採点（「この文章AIが書いた？」「AI臭さをスコアで出して」）、textlint の実行、「Gemini に」「別モデルで」「agy で」推敲させたい依頼のいずれでも発火する。検出は機械（lint.py / textlint）、語感の判断は別モデル（agy 経由の Gemini）、最終判断は自分、という分担で進める。文章の自然さ・読みやすさ・わかりやすさが対象で、技術文書の章構成やMarkdownの整形自体は扱わない。
license: MIT
argument-hint: "[write|polish|score|lint] [quick|full] [対象ファイルや依頼内容]"
---

# japanese

日本語の文章を、書く・直す・磨くためのスキル。読みやすく、人が書いたように読める状態まで持っていく。

**このファイルだけ最初に読む。**進めるレーンが決まったら、そのファイルを開く。`references/` は必要になったときだけ開く（大半は開かなくてよい）。

## 役割分担 — 機械は指さす、判断はAI、語感は別モデル

軸は二つ。第一に「検出は機械、判断はAI」。AIは自分の癖を認識しにくいので、疑いの検出は機械が決定的に行い、直すかどうかはAI（あなた）が文脈で判断する。第二に「事後修正より生成時制約」。書いた後にAI臭を消すより、書く前の設計と書くときの制約で発生自体を防ぐほうが効く。

日本語の語感そのものは、Claude / GPT より Gemini のほうが自然なことが多い。だから最終的な語感の判断は `agy`（Antigravity CLI）経由で Gemini に投げてよい。ただし**投げた結果は提案であって正解ではない**。差分を読んで採るか戻すかを決めるのは自分。

## レーンの選び方

| 依頼 | レーン | 読むファイル |
|---|---|---|
| ゼロから書く（議事録化・レポート・記事・メール等） | write | `lanes/write.md` |
| 既存の文章を直す・推敲する（既定の入口） | polish-self | `lanes/polish-self.md` |
| 「Gemini に」「別モデルで」「agy で」推敲させる、語感の最終パス | polish-external | `lanes/polish-external.md` |
| 診断だけ（スコア・AI臭さの判定、書き換えない） | score | `lanes/score.md`（読む前に必ず `references/diagnose.md`） |
| textlint を回す | lint | `lanes/textlint.md` |

迷ったら polish-self から入り、仕上げに polish-external を使うか判断する。「Gemini に」と明示されたら polish-external を直接使ってよい。

## 実行モード — クイックとフル

同じ工程を、かける手間の違う2つのモードで回す。目安はクイックが短い文書で30秒、1万字級でも3分。フルが短い文書で7分前後、1万字級で15〜20分。フルを始めるときは、この目安をユーザーに一言伝えてから着手する。

- **クイック（既定）**: 日常の文書。サブエージェントを使わず、追加で読むのは該当する doctype やカタログ1ファイルだけでよい。lint は文書が短くても省略しない（短文では統計系検出器が沈黙するが、禁止語・翻訳調は文1つでも出る）。収束ループは新しい finding が出なければ1周で切り上げる
- **フル**: 「しっかり」「ちゃんと」「時間をかけていい」と言われたとき、対外・経営向けなど失敗コストが高い文書、1万字超の長い文書。lint に加えて `outline.py` / `terms.py` も回し、「構造レビュー」と「読みやすさレビュー」を必ず行う。収束は状態条件を満たすまで回す

どちらか迷ったら、まずクイックで仕上げてから「フルで磨き直すこともできる」と添える。

effort（思考予算）を選べる環境でフルを回すなら high を推奨する。低い effort は工程を合理化で削りやすい。クイックは low で足りる。

## references の索引

必要なものだけ開く。

- 書くときの制約 → `references/writing-constitution.md`
- 文書タイプの型 → `references/doctypes/{minutes,report,guide,memo,slide}.md`
- 直し方の手順・判断台帳・濃淡設計・素材集め・発散ガード → `references/revision-guide.md`
- 禁止語・LLM常套句 → `references/forbidden-patterns.md`
- 翻訳調・英語統語 → `references/translationese.md`
- 語順・読点・一文一義の原則 → `references/readability-principles.md`
- 悪文パターン27種 → `references/readability-antipatterns.md`
- ジャンル別の判断差 → `references/genre-notes.md`
- uv が使えない環境の人手チェック → `references/manual-checklist.md`
- スコアの算出式と出力形式 → `references/diagnose.md`
- before/after の実例 → `references/examples.md`
- 自分の文体プロファイルを作る → `assets/style-profile-template.md`
