# Safari Web Extensionのときの補足

印の意味はSKILL.mdと同じ。【試した】は2026-10-02、iPhone Air（iOS 27.0）とiOS 27.0のシミュレータで、Safari Web Extension（アプリ＋拡張＋UIテスト）を実際に動かしたもの。

## 目次

1. ターゲットと署名
2. 拡張を有効にする
3. UIテストで拡張をオンにする・押す
4. iOS 27でHTTPのページを開くときの警告
5. ログの見方
6. Macで動かすとき
7. 気づいたこと

## 1. ターゲットと署名

- アプリ（コンテナ）と拡張（appex）の2つのターゲットに、同じチームと自動署名を入れる。拡張のBundle IDは`<アプリのBundle ID>.Extension`のようにアプリのIDで始める。
- 拡張が特別なentitlementを持たなければ、アプリ・拡張・UIテストのランナーのすべてが、チームのワイルドカードのプロファイル（`iOS Team Provisioning Profile: *`）で署名された。新しいApp ID・プロファイル・端末の登録は起きなかった【試した】。
- App Groupsでアプリと拡張がデータを分け合うときは、明示的なApp IDとApp Groupの登録が要る（ポータルが変わる。確認してから）【資料】。
- XcodeGenを使うときは、拡張のターゲットにも`settings.groups: [signing]`を付ける（`references/signing-config.md`）。

## 2. 拡張を有効にする

入れただけでは、拡張はオフのことがある。オンにするのは端末を持っている人の操作なので、ユーザーに頼むか、UIテストで行う（3）。

| 端末 | 場所 |
|---|---|
| iPhone | Safariのページメニュー →「機能拡張を管理」→ 拡張のスイッチ【試した】。または 設定＞アプリ＞Safari＞機能拡張【資料】 |
| iPad | アドレス欄の右の「機能拡張を管理」のボタン → 拡張のスイッチ【資料】 |
| Mac | アプリを一度起動してから、Safari＞設定＞機能拡張で拡張にチェック【資料】 |

- 拡張を押す場所：iPhoneはページメニューの中の拡張の名前、iPadは「機能拡張を管理」のボタン、Macはツールバーのボタン【iPhoneは試した、ほかは資料】。
- `activeTab`だけで`host_permissions`を持たない拡張では、押してもサイトの許可のダイアログは出なかった（拡張をオンにし直した直後でも）【試した】。`host_permissions`を持つ拡張では、サイトごとの許可を聞かれる【資料】。

## 3. UIテストで拡張をオンにする・押す

iOS 27.0のSafariの要素の名前【試した：実機とシミュレータで同じだった】：

| 要素 | 取り方 |
|---|---|
| Safari | `XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")` |
| ページメニューのボタン | `safari.buttons["MoreMenuButton"]` |
| 「機能拡張を管理」 | `safari.buttons["ManageExtensions"]` |
| 拡張のスイッチ | `safari.switches["<拡張の表示名>"]`（`value`が`"1"`ならオン） |
| 管理の画面を閉じる | `safari.buttons["完了"]`（日本語の端末）。なければ下へスワイプ |
| ページメニューの中の拡張 | `safari.buttons["<拡張の表示名>"]`。iOS 27.0のページメニューは長く、画面の外にあってもそのまま`tap()`できた |

```swift
let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")

func open(_ url: String) {
    XCUIDevice.shared.system.open(URL(string: url)!)
    XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15))
}

func enableExtension(_ name: String) {
    // 作ったばかりのシミュレータでは、ツールバーが出るまで時間がかかる。待たずに押すと失敗した
    XCTAssertTrue(safari.buttons["MoreMenuButton"].waitForExistence(timeout: 15))
    safari.buttons["MoreMenuButton"].tap()
    safari.buttons["ManageExtensions"].tap()
    let toggle = safari.switches[name]
    XCTAssertTrue(toggle.waitForExistence(timeout: 5), "管理の画面に拡張が出ない")
    if (toggle.value as? String) != "1" { toggle.tap() }
    let done = safari.buttons["完了"]
    if done.exists { done.tap() } else { safari.swipeDown() }
}
```

- 英語の端末では、ラベルが変わるもの（「完了」→`Done`など）がある。英語の端末では試していない。
- テストページのURLは、`TEST_RUNNER_`の接頭辞の環境変数で渡す（SKILL.mdの3節）。実機からは`127.0.0.1`のMacに届かないので、MacのLANのアドレスを渡す。
- Safariの初回の案内（「あとで設定」など）が出ることがある。出ていたら閉じる処理を入れておく（通ったテストに入っていた処理）。

## 4. iOS 27でHTTPのページを開くときの警告

- iOS 27.0の実機のSafariでHTTPのページを開くと、「この接続は安全ではありません」の画面に「続ける」と「戻る」が出た。**ページを開くたびに出た**【試した】。手で試すなら「続ける」を押してもらう。
- UIテストでは、開いた直後にボタンを押して進める【試した】：

  ```swift
  if url.hasPrefix("http:") {
      let proceed = safari.webViews.buttons
          .matching(NSPredicate(format: "label IN {'続ける', 'Webサイトを表示'}")).firstMatch
      if proceed.waitForExistence(timeout: 5) { proceed.tap() }
  }
  ```

  これを入れる前は、テストが「テストページが開かない」で失敗した。英語の端末のラベルは確かめていない。
- 自己署名の証明書のHTTPSにすれば警告は避けられるが、実機に証明書（CA）を入れて信頼する設定が要る。テストページをLANのHTTPで配るほうが手軽だった。
- MacでLAN向けにサーバを立てると、macOSのファイアウォールが許可を聞いてくることがある。答えるのはユーザー【資料】。

## 5. ログの見方

【別の作業の手順書（2026-10-02）より。ここでは試していない】

- content script：端末をつないだまま、MacのSafari＞開発＞〈端末の名前〉＞〈開いているページ〉。端末側で 設定＞アプリ＞Safari＞詳細＞Webインスペクタ をオンにしておく。
- background：MacのSafari＞開発＞〈端末の名前〉＞拡張のバックグラウンドページ。**Web Inspectorで開いている間はbackgroundがアンロードされない**ので、アンロードの振る舞いを調べるときは開かない。
- native（appex）：Console.app＞端末を選ぶ＞「開始」＞検索に`subsystem:<拡張のBundle ID>`（`os.Logger`の`subsystem`に拡張のBundle IDを使っている場合）。

## 6. Macで動かすとき

【資料。チームで署名したMac版は試していない】

- macOS向けにビルドしただけで（起動しなくても）、拡張がSafariに登録されることがある。
- チームで署名していれば、Safariの「未署名の機能拡張を許可」は要らない。要るのはad-hoc署名（チームなし）のときだけで、この設定はSafariを終了すると自動でオフに戻る。
- 古いビルドの登録が残って、一覧に同じ名前の拡張が2つ出ることがある。どこのビルドかは次で分かる：

  ```sh
  pluginkit -mAvvv -p com.apple.Safari.web-extension | grep -i -A2 '<拡張のBundle ID>('
  ```

  消すのは、ユーザーに確かめてから（`pluginkit -r <appexのパス>`、ビルドのフォルダの削除）。

## 7. 気づいたこと

- iOS 27.0の実機では、appexの冷えた起動は0.1秒前後で、シミュレータ（約2秒、最初の1回は約28秒）よりずっと速かった【試した】。シミュレータの時間でタイムアウトを決めない。
- iOS 27.0のSafariのUser-Agentは`iPhone OS 18_7 … Version/27.0`で、OSの版の部分は18_7のままだった【試した】。User-AgentでOSの版を判定しない。
