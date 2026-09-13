# レーン: polish — 推敲（既定）

推敲の依頼が来たら、まずこのレーン。流れは4段。

1. **検出** — `scripts/lint.py` でAI臭さの疑いを機械的に拾う
2. **書き換え** — `agy`（Antigravity CLI / Gemini）に推敲させる
3. **取捨** — 返ってきた差分を読み、採るか戻すかを自分で決める
4. **検証** — `scripts/lint.py --baseline` で指摘が本当に減ったか数える

`scripts/polish.sh` が1〜4を1回でやる。理由は役割分担。**自分で直しても語感は戻らない**——AI臭い日本語を書いたのと同じ系統のモデルが直すことになるから。lint は検出と検証が得意で、書き換えは苦手。語感の書き換えは別系統のモデル（Gemini）に渡し、採るか戻すかの判断だけを自分が持つ。

自分で直したいとき（agy を使えない環境、機密、数行の文）は `polish-without-agy.md` へ。

## 前提

- `agy` がインストールされていること（`brew install --cask antigravity-cli`、または公式スクリプト）
- Google アカウントでサインイン済みであること

```bash
agy --version          # 入っているか
agy models             # サインインできているか（モデル一覧が出ればOK）
```

未サインインなら、利用者に「実端末で `agy` を起動し、ブラウザで Google アカウントにサインインしてください」と伝える。`agy -p`（ヘッドレス）は制御端末がないと対話ログインを拒否するので、サインイン自体は実端末で行う。一度成功すれば macOS キーチェーンに保存され、以後は聞かれない。API キーは既定では不要（`~/.gemini/antigravity-cli/settings.json` に `{"modelProvider": "gemini"}` と `GEMINI_API_KEY` を渡す方式にもできる）。

## 使い方

```bash
# 差分と lint の増減を見るだけ（元ファイルは書き換えない。既定）
scripts/polish.sh draft.md

# 既定のモデルを変える（環境変数でも上書きできる）
JA_POLISH_MODEL=gemini-3.8-flash-low scripts/polish.sh draft.md
scripts/polish.sh -m gemini-3.8-flash-high report.md

# 修正後を別ファイルに書き出す（差分は常に表示される）
scripts/polish.sh -o draft.fixed.md draft.md

# 上書きする（.bak.<日時> を残す）
scripts/polish.sh -w draft.md

# 標準入力から / プロンプトだけ確認する
cat draft.md | scripts/polish.sh -
scripts/polish.sh --dry-run draft.md
```

主なオプションは `-m/--model`、`-e/--effort low|medium|high`、`-t/--timeout`、`-g/--genre business|essay|tech`、`-o/--output`、`-w/--write`、`--no-lint`、`--local-only`、`--policy-full`、`-p/--prompt "追加指示"`。全体は `--help` で出る。

**既定のモデルは `gemini-3.8-flash-medium`**（環境変数 `JA_POLISH_MODEL` でも変えられる）。agy のモデル名には effort が含まれる（`gemini-3.8-flash-low|medium|high`）ので、モデル名に `-low` / `-medium` / `-high` が付いているときは `--effort` を渡さず、名前のほうを正とする。`-e` を明示して食い違ったときは、無視した旨を stderr に出す。3.8 系は flash の3段階だけで、`lite` という名前のモデルは無い（`agy models` で一覧が出る）。

## 送信前の承認は取らない（既定）

本文は Google アカウント経由で Gemini に送られる。**既定ではこれを止めない。**「送っていいですか」と毎回聞くと、判断が長引いて作業が止まるだけで、得るものが無い。止めたい場所は先に宣言しておく。

- 環境変数: `JA_POLISH_EXTERNAL=off`
- プロジェクトに印を置く: プロジェクトルートに `.japanese-local-only`（空ファイルでよい）。`polish.sh` は対象ファイルのディレクトリから上に辿って探す
- 単発で止める: `scripts/polish.sh --local-only draft.md`

どれかが効いているとき、`polish.sh` は agy を呼ばず、lint の指摘だけを出して終わる。その結果を見て `polish-without-agy.md` に進む。`agy` が未導入・未サインインのときも同じ扱いで、自分で直すレーンに切り替える。

顧客名や社外秘が混ざる文書を扱うプロジェクトでは、最初に `.japanese-local-only` を置いておくのが安全。

## agy の出力をそのまま採用しない

agy は指示を守らず、まれに前置き（「以下が修正後です」）、意味の追加、段落の統合、Markdown 構造の変更を混ぜてくる。差分を必ず自分で読み、次のいずれかに当てはまる変更は戻す。

- **情報が増えている** — 原文にない事実・数値・固有名詞・説明が足されている（最も危険）
- **情報が消えている** — 条件・留保・例が落ちている
- **主張や論理が変わっている** — 断定が弱まる／強まる、因果が入れ替わる
- **構造が変わっている** — 見出しレベル、箇条書き、リンクURL、コードブロック、表の崩れ
- **語り口が変わっている** — 敬体と常体の混在、原文の比喩や言い回しの消去
- **過剰修正** — 直す必要のない文まで模様替えされ、原文の輪郭が消えている

逆に、次のような修正は素直に採ってよい。

- 曖昧な動詞の具体化（「効く」→「〜を短縮する」）
- 体言止めの述語補完、助詞の補完、名詞の羅列の解消
- 直訳調の言い換え（「〜することができる」→「〜できる」）
- LLM常套句の削除、強調の偏りの解消、文の長短の調整
- 表記・用語の統一

lint の増減は判断の材料であって結論ではない。**解消が増えても新規が出ていれば失敗**（別のAI臭さを作っただけ）。逆に件数が減らなくても、読みやすくなっていれば採用してよい。とくに `low_burstiness` や `low_lexical_diversity_ttr` のような統計系は文を書き換えないと動かないので、「件数が減らないから失敗」と即断しない。

全文を通すと差分が大きくなりがちなので、まず1ファイルで試してポリシーの効き方を見てから本番の文書に当てる。効きが弱い・強すぎるときは `prompts/policy.md` の「直す対象」「判断の原則」を調整する。

## スクリプトがやっていること

1. `scripts/lint.py --json` を回し、機械検出の指摘を「参考」としてプロンプトに同梱する（`--no-lint` で無効化）
2. `prompts/policy.md` の校正ポリシーと本文を `<doc>` で囲んで `agy -p` に渡す
3. 出力から本文だけを取り出し、元と `diff -u` で並べる
4. もう一度 lint を `--baseline` つきで回し、指摘が減ったか（解消 / 新規 / 継続）を数える

`--policy-full` を付けると `references/forbidden-patterns.md` と `references/translationese.md` も同梱する。語彙の指摘が甘いと感じたときに使う（トークンは増える）。

## 困ったとき

- **`agy が見つかりません`** — `brew install --cask antigravity-cli` を案内する
- **`agy が未サインインです`** — 実端末でのサインインを依頼する（上記「前提」）
- **`agy がツール呼び出しで止まりました`** — ヘッドレスではツール権限を確認できないため自動拒否される。`-p` の追加指示に「ツールは使わず本文だけを出力する」と明記するか、TUI 側で permissions を設定する
- **出力が空、またはタイムアウト** — `-t 10m` で延ばす、`-e low` で軽くする、入力を分割する
- **前置きやコードフェンスが混ざる** — 差分に出るので採用時に落とす。頻発するなら `prompts/policy.md` の「出力」節を強める
- **修正が過剰** — `prompts/policy.md` の「判断の原則」に「変更は最小限」「迷ったら触らない」を足して再実行する
- **`入力が大きすぎます`** — 章単位に分割する（プロンプトを argv で渡すため約40万バイトで止めている）
