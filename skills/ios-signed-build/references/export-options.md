# archiveと.ipaの書き出し（ExportOptions.plist）

印の意味はSKILL.mdと同じ（【試した】は2026-10-02、Xcode 27.0で通したもの、【資料】は試していないもの）。

## 目次

1. 流れ
2. methodの選び方
3. ExportOptions.plistの雛形
4. 試した結果とエラー文
5. できた.ipaを確かめる
6. .ipaを端末に入れる
7. TestFlight・App Storeに出す
8. XcodeのOrganizerから書き出す
9. 手動署名で書き出す

## 1. 流れ

```sh
# archive（ポータルに触れない。手元の証明書とプロファイルで署名する）
xcodebuild archive -project App.xcodeproj -scheme App \
  -destination 'generic/platform=iOS' -archivePath build/App.xcarchive

# 書き出し
xcodebuild -exportArchive -archivePath build/App.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export
```

- `-workspace App.xcworkspace`のプロジェクト（CocoaPodsなど）は`-project`の代わりに使う。
- archiveは、開発用の証明書（Apple Development）と開発用のプロファイルで署名される。書き出しのときに、methodに合った証明書とプロファイルで署名し直す【試した：archiveの`SigningIdentity`は`Apple Development`だった】【署名し直す部分は資料】。
- 小さなアプリで、archiveは約18秒、`debugging`の書き出しは約2秒だった【試した】。
- XcodeでProduct → Archiveしたものは`~/Library/Developer/Xcode/Archives/<日付>/<名前> <日付>, <時刻>.xcarchive`にある。`-archivePath`にそのまま渡せる【資料】。

## 2. methodの選び方

`xcodebuild -help`の「Available keys for -exportOptionsPlist」（Xcode 27）に出るmethodは、`app-store-connect`、`release-testing`、`enterprise`、`debugging`、`developer-id`、`mac-application`、`validation`。旧名の`app-store`・`ad-hoc`・`development`も通るが、非推奨の警告が出る【試した】。

| 依頼の例 | `method` | 旧名 | 入れられる端末 | 署名に使うもの |
|---|---|---|---|---|
| 「ipa作って」「自分のiPhoneに入れたい」「sideload用」 | `debugging` | `development` | プロファイルに入った端末 | Apple Development、開発用のプロファイル |
| 「テスターに配りたい」「Ad Hocで」 | `release-testing` | `ad-hoc` | プロファイルに入った端末 | Apple Distribution、Ad Hoc用のプロファイル |
| 「TestFlight用」「App Storeに出す」 | `app-store-connect` | `app-store` | TestFlight・App Storeから | Apple Distribution、App Store用のプロファイル |
| 社内の端末に配る | `enterprise` | — | 組織の端末 | Apple Developer Enterprise Programが要る（このスキルの対象外） |

- 迷ったら`debugging`。自分の登録済みの端末で動かすだけなら、これで足りる。`release-testing`と違い、配布用の証明書もAd Hoc用のプロファイルも要らない。
- `release-testing`も`debugging`も、プロファイルに入っていない端末には入らない。新しい端末に配るときは、端末の登録とプロファイルの作り直しが要る（ポータルが変わるので確認する）。
- AltStoreなどのサイドロード用の道具は、有料のチームなら要らない。`debugging`か`release-testing`の.ipaを、6の方法で入れる。

## 3. ExportOptions.plistの雛形

### debugging（開発用）【試した】

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>debugging</string>
	<key>destination</key>
	<string>export</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>ABCDE12345</string>
</dict>
</plist>
```

`PlistBuddy`で作るなら：

```sh
/usr/libexec/PlistBuddy -c "Add :method string debugging" -c "Add :destination string export" \
  -c "Add :signingStyle string automatic" -c "Add :teamID string ABCDE12345" ExportOptions.plist
```

### release-testing（Ad Hoc）

上の`method`を`release-testing`にする。初回は配布用の証明書とAd Hoc用のプロファイルが手元にないことが多く、そのときは`-allowProvisioningUpdates`が要る（4）。ポータルが変わるので、ユーザーに確認してから付ける。

### app-store-connect（TestFlight・App Store）

`method`を`app-store-connect`にする。`destination`が`export`なら手元に.ipaを書き出すだけ、`upload`ならApp Store Connectへ送る（7）。必要に応じて次のキーを足す【資料】：

| キー | 意味 |
|---|---|
| `testFlightInternalTestingOnly` | `true`なら、そのビルドは内部テストだけに使え、外部のTestFlightやApp Storeには出せない |
| `manageAppVersionAndBuildNumber` | アップロードのときにXcodeがビルド番号を管理するか（既定は`YES`） |
| `uploadSymbols` | シンボルを含めるか（既定は`YES`） |

- `teamID`は、省略するとarchiveのときのチームになる【資料】。
- キーの一覧と説明は`xcodebuild -help`の末尾にある。版が変わったら、まずそこを見る。

## 4. 試した結果とエラー文

小さなアプリ（特別なcapabilityなし、Bundle IDはチームのワイルドカードのプロファイルで署名できるもの）のarchiveを、`-allowProvisioningUpdates`なしで書き出した【試した】。

| method | 結果 |
|---|---|
| `debugging` | 通った。プロファイルは`iOS Team Provisioning Profile: *` |
| `development`（旧名） | 通った。`Command line name "development" is deprecated. Use "debugging" instead.` |
| `release-testing` | `error: exportArchive No profiles for '<Bundle ID>' were found`／`Xcode couldn't find any iOS Ad Hoc provisioning profiles matching '<Bundle ID>'. Automatic signing is disabled and unable to generate a profile. To enable automatic signing, pass -allowProvisioningUpdates to xcodebuild.`（終了コード70） |
| `app-store-connect` | 同じ形で`iOS App Store provisioning profiles`が見つからない（終了コード70） |

- 止まったら、エラー文の「iOS Ad Hoc」「iOS App Store」のところで、何が作られるかが分かる。ユーザーに「このBundle IDの〈Ad Hoc用／App Store用〉のプロファイルを作る（配布用の証明書がなければそれも）」と伝えて、`-allowProvisioningUpdates`を付けてよいかを聞く。
- 付けたときの振る舞い（`xcodebuild -help`の`signingStyle`の説明より）：archiveが手動署名で、書き出しを自動署名にすると、Xcodeはプロファイルとクラウドで管理される配布用の証明書を必要に応じて作る。ただし、端末の登録、App IDの登録、App IDの設定の変更はしない【資料】。
- 手元にある配布用のプロファイルは`scripts/list-profiles.py <Bundle ID>`で見られる（`ad-hoc`・`app-store`の行）。

## 5. できた.ipaを確かめる

```sh
ls build/export                 # <名前>.ipa、DistributionSummary.plist、ExportOptions.plist、Packaging.log
unzip -l build/export/App.ipa   # Payload/App.app/… が入っている
plutil -p build/export/DistributionSummary.plist   # 使われた証明書の種類・期限、プロファイルの名前・UUID、entitlements
```

【試した】`DistributionSummary.plist`には証明書のSHA-1も入っている。ユーザーに見せるときは、種類・期限・プロファイルの名前だけでよい。

アプリの署名そのものは、取り出して`codesign`で読む（アプリの署名を読むだけで、キーチェーンには触れない）【試した：archiveの中の.appで】：

```sh
codesign -dvv build/App.xcarchive/Products/Applications/App.app 2>&1 | grep -E 'Identifier|Authority|TeamIdentifier'
codesign -d --entitlements - --xml build/App.xcarchive/Products/Applications/App.app | plutil -p -
```

`get-task-allow`が`true`なら開発用の署名（`debugging`）、配布用なら`false`。

## 6. .ipaを端末に入れる

【展開と署名の検証までは試した。端末に入れるところは試していない】

- `xcrun devicectl device install app`のヘルプは、`.app`を入れると書いている。.ipaを入れるときは、展開して中の`.app`を渡す：

  ```sh
  rm -rf build/ipa && mkdir -p build/ipa && unzip -q build/export/App.ipa -d build/ipa
  codesign --verify --deep --strict build/ipa/Payload/App.app   # 展開しても署名が壊れていないか
  xcrun devicectl device install app --device "$UDID" build/ipa/Payload/App.app
  ```

  展開した`.app`は`valid on disk`・`satisfies its Designated Requirement`になった【試した】。

- ほかに、FinderのサイドバーでiPhoneを選んで.ipaをドラッグする、Apple Configuratorを使う、XcodeのDevices and Simulatorsのウインドウの「+」から入れる、がある。
- テスターに渡すなら`release-testing`の.ipaを送り、テスターが上のいずれかで入れる。テスターの端末は、先にプロファイルに入っている必要がある。

## 7. TestFlight・App Storeに出す

【資料。アップロードは試していない。アップロードは外に出る操作なので、必ずユーザーに確認してから】

前提：

- App Store Connectに、そのBundle IDのアプリが登録されていること（なければユーザーに作ってもらう）
- ビルド番号（`CURRENT_PROJECT_VERSION`）が、前に上げたものと重ならないこと（`manageAppVersionAndBuildNumber`を`YES`にすると、Xcodeが管理する）
- 配布用の証明書とApp Store用のプロファイル（なければ`-allowProvisioningUpdates`で作る。確認してから）

やり方：

1. `method`を`app-store-connect`、`destination`を`upload`にして、`xcodebuild -exportArchive … -allowProvisioningUpdates`で送る。
2. または、`destination`を`export`にして.ipaを作り、`xcrun altool --upload-package <.ipa> …`かTransporterのアプリで送る。`altool`の認証には、App Store ConnectのAPIキーなどが要る（`xcrun altool --help`）。
3. または、XcodeのOrganizerで「Distribute App」→「TestFlight & App Store」。

`-authenticationKeyPath`・`-authenticationKeyID`・`-authenticationKeyIssuerID`で、App Store ConnectのAPIキーを使って`-allowProvisioningUpdates`を通すこともできる（CIなど、Xcodeにサインインしていない環境向け）【資料】。

## 8. XcodeのOrganizerから書き出す

【資料】Window → Organizer → Archives → 対象を選んで「Distribute App」→「Custom」で、「Debugging」（旧Development）・「Release Testing」（旧Ad Hoc）・「App Store Connect」を選べる。有料のチームなら、無料のPersonal Teamで出ていた「ADP membership required」のエラーは出ない。Organizerの書き出しは、自動署名ならXcodeがポータルにつないで、プロファイルや証明書を作ることがある。ユーザーに頼むときは、そのことを先に伝える。

## 9. 手動署名で書き出す

```xml
<key>signingStyle</key>
<string>manual</string>
<key>signingCertificate</key>
<string>Apple Distribution</string>
<key>provisioningProfiles</key>
<dict>
	<key>com.example.App</key>
	<string>〈プロファイルの名前かUUID〉</string>
	<key>com.example.App.Extension</key>
	<string>〈拡張のプロファイルの名前かUUID〉</string>
</dict>
```

- `provisioningProfiles`には、アプリと拡張のすべてのBundle IDを書く【資料】。
- Xcodeが管理するプロファイル（自動署名が作ったもの。`list-profiles.py`で「Xcode管理」と出るもの）は、手動署名では使えない。`Provisioning profile "iOS Team Provisioning Profile: *" is Xcode managed, but signing settings require a manually managed profile.`で止まった【試した】。手動署名にするなら、ポータルで手動のプロファイルを作る必要がある（確認してから）。ふつうは自動署名のままでよい。
