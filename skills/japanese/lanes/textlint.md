# レーン: lint — textlint で機械チェックする

ルールベースの機械チェック。`scripts/lint.py` とは別系統で、`~/.textlintrc` の設定に従って Markdown を検査する。両者は役割が近いが、こちらは設定ファイルで運用が決まる。併用してよい。

## 前提

- textlint はグローバルインストール済みで、`textlint` コマンドを直接使える
- 設定は `~/.textlintrc`（正本は dotfiles の `textlint/.textlintrc`）
- プロジェクトに `.textlintrc` があればそちらが優先される

## 手順

1. 対象をチェックする

   ```bash
   textlint "**/*.md"
   ```

   特定のファイルだけなら個別指定でもよい（`textlint docs/foo.md`）。

2. 機械的に直せるものは自動修正する

   ```bash
   textlint --fix "**/*.md"
   ```

3. `--fix` の後に再実行し、残った指摘を確認する

4. 残った指摘は文脈を見て、日本語として自然になるよう手動で修正する
   - textlint の提案は機械的なので、そのまま貼らずに言い回しを調整する
   - 修正後は必ず読み直して自然さを確認する
   - 判断に迷う表現は `references/forbidden-patterns.md` の該当節（理由の説明がある）を参照する

## 補足

- 指摘が多いときは `--quiet` でエラーだけ表示し、エラー → 警告の順に対応する
- ルールの追加・調整（許可表現など）は `~/.textlintrc` の `rules` を編集する
- 対象外にしたいファイルは `.textlintignore` に追記する
- 文書全体の自然さ（構成・濃淡・語順）は textlint では見えない。`polish.md` と併用する
