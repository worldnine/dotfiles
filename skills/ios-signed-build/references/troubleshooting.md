# よくある問題

印の意味はSKILL.mdと同じ（【試した】は2026-10-02に実際に見たもの、【資料】は試していないもの）。エラー文は版によって変わることがある。

**先に決めておくこと：**ポータルを変える操作（App ID・端末・証明書・プロファイルの作成、アップロード）と、キーチェーン・端末の画面での操作は、こちらでは行わない。何が要るかを説明して、ユーザーに確認するか、操作を頼む。証明書の失効は、勧められても選ばない。

## 目次

1. プロファイル・App ID
2. 端末の登録
3. チーム・アカウント
4. 証明書・キーチェーン
5. 端末の状態（ロック、デベロッパモード、UI Automation、ペアリング）
6. テストの実行
7. 書き出し

## 1. プロファイル・App ID

### `No profiles for '<Bundle ID>' were found`

```text
error: exportArchive No profiles for 'com.example.App' were found
Xcode couldn't find any iOS Ad Hoc provisioning profiles matching 'com.example.App'. Automatic signing is disabled and unable to generate a profile. To enable automatic signing, pass -allowProvisioningUpdates to xcodebuild.
```

- 【試した：書き出しで`release-testing`・`app-store-connect`のとき】ビルドやarchiveでも、手元に合うプロファイルがなければ同じ形で止まる【資料】。
- 原因：手元に、そのBundle ID・その種類（開発用・Ad Hoc用・App Store用）のプロファイルがない。
- 対処：`scripts/list-profiles.py <Bundle ID>`で手元にあるものを見る。足りないものを、ユーザーに「このBundle IDの〈種類〉のプロファイルを作る。新しいBundle IDなら（明示的なApp IDが要るcapabilityがあれば）App IDも登録される」と伝え、`-allowProvisioningUpdates`を付けてよいかを聞く。

### Bundle IDが登録できない

- 例：`The app identifier "com.example.App" cannot be registered to your development team because it is not available.`【資料】
- 原因：そのBundle IDが、ほかのチームに登録済み。
- 対処：Bundle IDの頭を、自分のチームのもの（`com.example.yourname`など）に変える。ローカルのxcconfigで切り替えている場合は、`APP_BUNDLE_ID_PREFIX`の1行で済む（`references/signing-config.md`）。

### capabilityを足したら署名が通らなくなった

- 原因：App Groups・Push通知・iCloudなどは、ワイルドカードのプロファイルでは署名できない。明示的なApp IDと、そのcapabilityを有効にしたプロファイルが要る【資料】。
- 対処：ポータルでApp IDの設定が変わる。ユーザーに確認してから`-allowProvisioningUpdates`で流すか、Xcodeの画面で直してもらう。

## 2. 端末の登録

### 端末がプロファイルに入っていない

- 例：`Provisioning profile "iOS Team Provisioning Profile: *" doesn't include the currently selected device "<端末の名前>" (identifier <UDID>).`【資料】
- 確かめ方：`scripts/list-profiles.py <Bundle ID> <UDID>`で「端末なし」と出る【試した：スクリプトの表示】。
- 対処：端末の登録が要る。登録の枠は会員の年ごとに数え、消しても枠は戻らない【資料】。ユーザーに確認してから、`-allowProvisioningUpdates -allowProvisioningDeviceRegistration`を付けて、その端末を`-destination "platform=iOS,id=<UDID>"`で指定して流す。登録済みの端末で付けて流したときは、新しい登録は起きなかった【試した】。

### 端末の登録の枠がいっぱい

- 対処：古い端末を外すのは、会員の更新のときにポータルで行う（ユーザーの操作）【資料】。こちらからは何もしない。

## 3. チーム・アカウント

### `Signing for "<ターゲット>" requires a development team.`

- 【試した】`DEVELOPMENT_TEAM`が空のまま、実機向けにビルド・archiveした。
- 対処：SKILL.mdの0でTeam IDを調べ、ターゲットに入れる（`references/signing-config.md`）。一度だけならコマンドラインで`DEVELOPMENT_TEAM=<Team ID>`。

### `Invalid credentials in keychain`

```text
DVTDeveloperAccountManager: Failed to load credentials for <UUID>: … Invalid credentials in keychain
```

- 【試した】`-allowProvisioningUpdates`を付けたビルドの始めに出たが、署名とビルドは通った。Xcodeに登録されたアカウントのうち、どれかの資格情報が古いらしい。
- 対処：署名とビルドが通っていれば、作業は続けてよい。ユーザーには伝えておく。ポータルとのやりとり（プロファイルの作成など）で失敗するなら、ユーザーにXcodeの設定＞Accountsでそのアカウントにサインインし直してもらう【資料】。キーチェーンの項目をこちらで調べたり消したりしない。

### アカウントがない・チームが見つからない

- 例：`No Accounts: Add a new account in Accounts settings.`、`No Account for Team "<Team ID>"`【資料】
- 対処：`-allowProvisioningUpdates`はXcodeに登録されたアカウントを使う。ユーザーに、Xcodeの設定＞Accountsで、そのチームに入っているApple Accountを足してもらう。CIなどでは、App Store ConnectのAPIキー（`-authenticationKeyPath`・`-authenticationKeyID`・`-authenticationKeyIssuerID`）も使える【資料】。

### 無料のPersonal Teamしかない

- 見え方：`defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier`で`isFreeProvisioningTeam = 1`【資料】。
- 対処：このスキルの前提（有料のチーム）を満たさない。ad-hoc・TestFlightへの書き出しはできない。ユーザーに伝えて、どうするかを聞く。

## 4. 証明書・キーチェーン

### 開発用・配布用の証明書がない

- 例：`No signing certificate "iOS Development" found`、`No "Apple Distribution" signing certificate matching team ID "<Team ID>" with a private key was found.`【資料】
- 原因：このMacのキーチェーンに、その種類の証明書と秘密鍵がない（新しいMac、別のMacで作った証明書など）。
- 対処：次のどちらかをユーザーに選んでもらう。
  - `-allowProvisioningUpdates`で新しい証明書を作る（ポータルが変わる。証明書には数の上限がある【資料】）。
  - 証明書を作ったMacから、秘密鍵ごと書き出して（.p12）このMacに入れる（ユーザーの操作）。
- 証明書を失効させる案は選ばない。Xcodeが「Revoke」を勧めても、ユーザーに伝えるだけにする。

### キーチェーンの許可のダイアログで止まる

- 見え方：`xcodebuild`が`CodeSign`の段階から進まない。Macの画面に「codesignがキーチェーンの“…”にアクセスしようとしています」が出ている【資料。2026-10-02の作業では一度も出なかった】。
- 対処：ユーザーに、Macの画面を見て、ログインのパスワードを入れて「常に許可」を押してもらう。こちらで`security unlock-keychain`や`security set-key-partition-list`を使って避けない（キーチェーンの中身に触れることになるため）。
- SSHなど画面のない環境から署名すると、ダイアログを出せずに`errSecInternalComponent`で失敗することがある【資料】。ユーザーのMacのターミナルから流してもらう。

### 証明書の有無を確かめたい

- キーチェーンを読まずに確かめる。ビルドのログの`Signing Identity:`の行、できたアプリの`codesign -dvv <.app>`の`Authority=`の行、書き出しの`DistributionSummary.plist`の`certificate`の項目【試した】。一覧が要るなら、ユーザーにXcodeの設定＞Accounts＞〈チーム〉＞Manage Certificatesで見てもらう。

## 5. 端末の状態

### ロックされている

- 見え方：インストール・起動・UIテストが、端末がロックされている旨のエラーで失敗する【資料】。
- 対処：ユーザーにロックを解いてもらう。長いUIテストの間は、設定＞画面表示と明るさ＞自動ロックを「なし」にしてもらい、終わったら戻してもらう。
- 起動（`devicectl device process launch`）が通れば、そのときはロックされていない【試した】。テストの前に確かめるのに使える。

### デベロッパモードがオフ

- 確かめ方：`xcrun devicectl list devices --filter "Reality = 'physical'" --columns deviceProperties.developerModeStatus`が`enabled`でない【試した：`enabled`の表示】。
- 対処：ユーザーに、端末の 設定＞プライバシーとセキュリティ＞デベロッパモード をオンにしてもらう。端末の再起動と、再起動後の確認が要る。この項目は、端末を一度Xcodeにつなぐまで出ないことがある【資料】。

### UI Automationがオフ

- 見え方：実機でUIテストが始まらない、または端末側で許可を求められる【資料。2026-10-02の作業では、すでに使える状態で、何も聞かれなかった】。
- 対処：ユーザーに、端末の 設定＞デベロッパ で「UI Automation」をオンにしてもらう【資料】。

### 端末が一覧に出ない・`unavailable`

- 対処：ユーザーに、ロックを解いて、ケーブルでつないで、「このコンピュータを信頼」に答えてもらう。Wi-Fiで使うなら、Macと同じネットワークにいて、一度ペアリングしてあること【資料】。Wi-Fiでペアリング済みの端末は、ケーブルなしでインストール・UIテストまでできた【試した】。

### 起動すると「信頼されていないデベロッパ」

- 対処：ユーザーに、端末の 設定＞一般＞VPNとデバイス管理 で、そのデベロッパを信頼してもらう【資料。有料のチームの開発用の署名では、2026-10-02の作業では出なかった】。

## 6. テストの実行

### `-resultBundlePath`のパスがすでにある

- 対処：同じパスに`.xcresult`があると失敗する。流す前に消す（`rm -rf build/run.xcresult`）【別の作業の記録より】。

### テストのコードを変えたのに反映されない

- 対処：`test-without-building`は前のビルドを使う。`build-for-testing`からやり直す【別の作業の記録より】。

### シミュレータでは通るのに実機で止まる

- よくあるもの：テスト用のサーバのURL（実機からMacの`127.0.0.1`には届かない。`TEST_RUNNER_`で渡す）、実機だけで出る画面（HTTPの警告、初回の案内）、ロック【試した】。Safari Web Extensionなら`references/safari-web-extension.md`。

## 7. 書き出し

### `Command line name "development" is deprecated. Use "debugging" instead.`

- 【試した】書き出しは通る。`ExportOptions.plist`の`method`を新しい名前にする（`ad-hoc`→`release-testing`、`app-store`→`app-store-connect`）。

### `… is Xcode managed, but signing settings require a manually managed profile.`

- 【試した】`signingStyle: manual`で、自動署名が作ったプロファイルを指定した。
- 対処：`signingStyle: automatic`にする。手動署名にこだわるなら、ポータルで手動のプロファイルを作る必要がある（確認してから）。

### `No profiles for '<Bundle ID>' were found`（書き出し）

- 1の同じ見出しのとおり。`debugging`なら開発用のプロファイルで通ることが多い。配りたい相手と端末を聞いて、`debugging`で足りないかを先に確かめる。
