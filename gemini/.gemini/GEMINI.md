必ず日本語で丁寧に返答してください。

## Herdrで他のエージェントに作業を振るとき

herdrで他のエージェントに作業させるよう頼まれたら、herdrスキルの手順に加えて次を守る:

- タスクごとに`herdr worktree create --cwd <リポジトリのパス> --branch <name> --no-focus`でworktreeを切り、開いたペインでエージェントを起動する
- 起動したら、そのペインに親の印を付ける: `herdr pane report-metadata <ペイン> --source orchestrator --token parent=$HERDR_PANE_ID`
- 全員に仕事を渡してから待つ（1体ずつ完了を待たない）
- 作業用のエージェントには、自分のブランチへのコミットまでをさせる。マージはユーザーが判断する
- 仕事を渡すときは、最後に報告を返すよう指示する（変更内容・ブランチ・コミット・テスト結果・未解決の点）
- 全員が完了するか止まるまで、自分の番を終えない。各自の報告を`herdr agent read`で回収し、まとめてユーザーに返す
- 状況を確かめるときは、`herdr agent list`で`tokens.parent`が自分の`$HERDR_PANE_ID`になっているエージェントだけを自分の子として扱う（`herdr agent list | jq -r --arg me "$HERDR_PANE_ID" '.result.agents[] | select(.tokens.parent == $me) | .name'`）。印が無いものや、他のペインの印が付いたものには触らず、親が分からないとユーザーに伝える
- 承認や信頼の確認で止まったエージェントには答えず、報告の中でユーザーに知らせる。待ちがタイムアウトしたら、仕事を送り直さずに待ち直す
