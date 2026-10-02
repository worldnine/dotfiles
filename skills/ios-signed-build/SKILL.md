---
name: ios-signed-build
description: 有料のApple Developer Programのチームで、iOS・iPadOSのアプリ（Safari Web Extensionなどの拡張を含む）を署名してビルドし、実機に入れる・実機でUIテストを流す・archiveして.ipaを書き出すためのスキル。Team IDの調べ方と有料チームの見分け方、自動署名とDEVELOPMENT_TEAM、ローカルのxcconfigやXcodeGenでの署名の切り替え、xcodebuildの-allowProvisioningUpdates、xcrun devicectlでの端末の一覧・インストール・起動、ExportOptions.plistのmethodの選び方（debugging／release-testing／app-store-connect）、署名のエラーの直し方を扱う。「ipa作って」「.ipa作成」「ipa化」「Archiveからipa」「sideload用にipa」「AltStore用にビルド」「実機に入れて」「iPhoneで動かして」「署名してビルド」「プロファイルのエラー」「devicectl」「TestFlight用にarchive」「Ad Hocで配りたい」や、"build an ipa", "export ipa", "install on my iPhone", "run on a physical device", "code signing", "provisioning profile", "xcodebuild archive", "exportArchive", "ExportOptions.plist", "TestFlight build"と言われたら必ず使う。XcodeでProduct → Archiveをした直後に配りたい様子が見えたとき、実機向けのビルドが署名で止まったときにも使う。シミュレータだけで済む作業には使わない。
---

# ios-signed-build

有料のApple Developer Programのチームで署名して、iOS・iPadOSのアプリを実機に入れる、実機でテストする、.ipaにする、までの手順。特定のプロジェクトに依存しない。

シミュレータだけで済む作業（ビルド・テスト・スクリーンショット）は、このスキルではなく`xcodebuildmcp`スキルやXcodeBuildMCPを使う。

## 確かめた度合いの印

本文と`references/`の手順には、次の印を付けている。【資料】の手順は、初めて流すときに結果をよく見て、違っていたらユーザーに伝える。

- 【試した】2026-10-02に、Xcode 27.0（27A266a）、macOS 27.2、XcodeGen 2.44.1、devicectl 642.16、有料の個人チームで実際に通した。archive・書き出し・端末なしの`build-for-testing`・読むだけのコマンドは、このスキルを書くときに使い捨ての小さなアプリで試した。実機へのインストール・起動・UIテストと、Safari Web Extensionのことは、同じ日に同じMacとiPhone Air（iOS 27.0）で、別の作業（Safari Web Extensionの実機確認）で通したもの
- 【資料】`xcodebuild -help`・`man xcodebuild`・`devicectl`のヘルプ・Appleの資料から書いた。手元では試していない

## 守ること（最初に読む）

1. **Developerポータルを変える操作の前に、ユーザーに確認する。**
   - 該当するもの：新しいApp IDの登録、端末の登録、証明書（特に配布用のApple Distribution）の作成、Ad Hoc用・App Store用のプロファイルの作成、App Store Connectへのアップロード
   - `xcodebuild`の`-allowProvisioningUpdates`は、自動署名のターゲットについて「プロファイル・App ID・証明書を作る、更新する」ことを許すフラグ。`-allowProvisioningDeviceRegistration`は端末の登録を許す（`-allowProvisioningUpdates`と組で効く）【資料】。どちらも、付ける前に確認する
   - XcodeでRunする・Organizerから書き出すときも、自動署名ならXcodeが自分でポータルにつなぐことがある【資料】。ユーザーにXcodeの操作を頼むときも、作られうるものを先に伝える
   - 確かめ方：**まずフラグを付けずに流す。**手元のプロファイルと証明書で足りれば、そのまま通る（ポータルには何もしない）【試した】。止まったら、エラー文から「何が作られるか」を説明して、付けてよいかを聞く（`references/troubleshooting.md`）
   - 端末の登録の枠は、会員の年ごとに数える。消しても枠は戻らない【資料】。新しい端末の登録は特に慎重に
   - 一度承認をもらった組み合わせ（同じプロジェクト・同じ端末）を同じ作業の中で流し直すときは、聞き直さなくてよい
2. **証明書を失効（Revoke）しない。**Xcodeの画面や`xcodebuild`のエラーが失効や作り直しを勧めても、選ばずにユーザーに伝える。
3. **キーチェーンの中身を読まない。**`security find-identity`、`security dump-keychain`、`security find-*-password`、`security set-key-partition-list`、`security unlock-keychain`は使わない。証明書は、ビルドのログの`Signing Identity:`の行や、できたアプリの`codesign -dvv`（アプリの署名を読むだけ）で確かめる。キーチェーンの許可のダイアログが出たら、ユーザーに答えてもらう。
4. **端末に入れる・起動する・テストを流すのは、ユーザーに頼まれたときだけ。**端末は別の作業で使われていることがある。端末の一覧（`devicectl list devices`）を見るのはかまわない。

## 0. 下調べ（読むだけ。ポータルにも端末にも触れない）

### Team IDと、有料のチームか

```sh
defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier
```

```text
{
    "<アカウントのUUID>" =     (
                {
            isFreeProvisioningTeam = 0;
            teamID = ABCDE12345;
            teamName = "…";
            teamType = Individual;
        }
    );
}
```

- Xcodeにサインインしたアカウントごとに、入っているチームが出る。`teamID`がTeam ID（10文字）【試した】。
- `isFreeProvisioningTeam = 0`が有料のチーム【試した】。`1`は無料のPersonal Team【資料。手元では見ていない】。Personal Teamしかなければ、このスキルの手順（ad-hoc・TestFlightへの書き出しなど）は通らないので、ユーザーに伝える。
- チームが複数出たら、どれを使うかユーザーに聞く。ほかの調べ方：developer.apple.comの「メンバーシップの詳細」、Xcodeの設定＞Accounts。

### 端末

```sh
xcrun devicectl list devices --filter "Reality = 'physical'" --columns deviceProperties.developerModeStatus
```

```text
Name           Hostname   Identifier                         State                Model                     Reality    deviceProperties.developerModeStatus
------------   --------   --------------------------------   ------------------   -----------------------   --------   ------------------------------------
my-iphone                 00008150-0000000000000000 (UDID)   available (paired)   iPhone Air (iPhone18,4)   physical   enabled
```

- Xcode 27の`list devices`はシミュレータも並べるので、`Reality = 'physical'`で絞る【試した】。
- `Identifier`がUDID。`--device`には、UDIDのほか端末の名前も渡せる【資料】。
- `State`は`available (paired)`か`connected`なら使える。Wi-Fiでペアリング済みなら、ケーブルなしで入れられた【試した】。
- `developerModeStatus`が`enabled`でなければ、デベロッパモードをオンにしてもらう（`references/troubleshooting.md`）。
- UDIDだけ欲しいとき：`--hide-default-columns --columns Identifier --hide-headers`【試した】。

### 手元のプロファイル（ポータルを変えずに済むかの見込み）

```sh
python3 <このスキルのディレクトリ>/scripts/list-profiles.py <Bundle ID> [UDID]
```

```text
development  2027-06-18  ABCDE12345.*        devices=3   Xcode管理 端末あり  "iOS Team Provisioning Profile: *"  <プロファイルのUUID>
```

- そのBundle IDに効くプロファイル（完全一致とワイルドカード）と、端末が含まれるかを出す。ファイルを読むだけで、キーチェーンにもポータルにも触れない【試した】。
- `development`で`端末あり`のものがあれば、開発用のビルドはポータルを変えずに通る見込みが高い。特別なcapabilityのないアプリなら、チームのワイルドカードのプロファイル（`iOS Team Provisioning Profile: *`）で、アプリ・拡張・UIテストのランナーのすべてが署名された【試した】。
- App Groups・Push通知・iCloudなど、明示的なApp IDが要るcapabilityを持つアプリは、ワイルドカードでは足りない。初回は`-allowProvisioningUpdates`でApp IDとプロファイルが作られる【資料】。確認してから。

### プロジェクトの署名の設定

```sh
sh <このスキルのディレクトリ>/scripts/show-signing.sh                 # カレントの.xcodeprojの全ターゲット
sh <このスキルのディレクトリ>/scripts/show-signing.sh -workspace App.xcworkspace -scheme App -destination 'generic/platform=iOS'
```

```text
TARGET                           SDK                STYLE      IDENTITY             TEAM         BUNDLE_ID
SignProbe                        iphoneos27.0       Automatic  Apple Development    ABCDE12345   com.example.SignProbe
SignProbeUITests                 iphoneos27.0       Automatic  Apple Development    ABCDE12345   com.example.SignProbe.UITests
```

`xcodebuild -showBuildSettings`を読むだけで、ビルドも署名もしない【試した】。全ターゲットが`Automatic`・`Apple Development`・使うTeam IDになっていれば、1へ進まずに2へ進んでよい。

## 1. 署名の設定

基本は**自動署名（`CODE_SIGN_STYLE = Automatic`）＋`DEVELOPMENT_TEAM`**。`CODE_SIGN_IDENTITY`は`Apple Development`（旧名`iPhone Developer`）。

- アプリ・拡張・ウィジェット・UIテストの**全ターゲット**に同じチームを入れる。拡張のBundle IDは、アプリのBundle IDの後ろに`.Extension`などを付けた形にする【資料】。
- Team IDをリポジトリにコミットしたくないときは、**コミットしないローカルのxcconfig**で切り替える。ローカルのファイルにTeam IDとBundle IDの頭の2行だけを書けば、全ターゲットが自動署名になり、ファイルがなければad-hoc署名（シミュレータ用）に戻る形を作れる【試した】。書き方は`references/signing-config.md`。
- **XcodeGenを使うとき：**XcodeGenのプリセットは、iOSアプリのターゲットに`CODE_SIGN_IDENTITY = iPhone Developer`をターゲットの階層で書く。プロジェクトに読み込んだxcconfig（特に`#include?`の先）の値では上書きできない【試した】。`settingGroups`で全ターゲットに署名の値を明示する（`references/signing-config.md`）。`iPhone Developer`のままでも自動署名は`Apple Development`の証明書を選んでarchiveまで通ったが【試した】、意図をはっきりさせるため明示する。
- XcodeGenのプロジェクトでは、XcodeのSigning & Capabilitiesの画面で変えない。`xcodegen generate`のたびに消える。
- 一度だけ別のチームで試すなら、コマンドラインで渡せる：`xcodebuild archive … DEVELOPMENT_TEAM=ABCDE12345`【試した】。コマンドラインの値はSwift Packageを含む全ターゲットに効く。
- チームが入っていないと、`Signing for "<ターゲット>" requires a development team.`で止まる【試した】。

## 2. 実機向けにビルドして入れる

```sh
UDID=00008150-0000000000000000   # 0の「端末」で調べた値

# 1) フラグなしでビルドする（ポータルに触れない）
xcodebuild build -project App.xcodeproj -scheme App \
  -destination "platform=iOS,id=$UDID" -derivedDataPath build

# 2) 1が「プロファイルがない」「端末が入っていない」で止まったら、ユーザーに確認してから付け直す
xcodebuild build -project App.xcodeproj -scheme App \
  -destination "platform=iOS,id=$UDID" -derivedDataPath build \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration

# 3) 入れて、起動する（起動できれば端末はロックされていない）
xcrun devicectl device install app --device "$UDID" build/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device "$UDID" --terminate-existing <アプリのBundle ID>
```

- 実際に通した形は、`build`ではなく`build-for-testing`（3節）に2のフラグを付けたもの。初回は約30秒、2回目以降は約10秒だった【試した】。署名は、ログの`Signing Identity: "Apple Development: …"`と`Provisioning Profile: "…"`の行で確かめる。このときは、新しいApp ID・プロファイル・端末の登録は起きなかった（端末は登録済みで、ワイルドカードのプロファイルを使った）。
- `devicectl device install app`は`.app`を入れる（ヘルプの記述）【試した】。`App installed: bundleID: …`、`Launched application with … bundle identifier.`が出れば済み。
- 起動するアプリに環境変数を渡す：`DEVICECTL_CHILD_`の接頭辞を付けて呼ぶか、`-e '{"KEY":"VALUE"}'`【資料】。標準出力を見るなら`--console`【資料】。
- ほかに：`xcrun devicectl device info apps --device "$UDID"`（入っているアプリ）、`xcrun devicectl device uninstall app --device "$UDID" <Bundle ID>`（消す）【資料】。

## 3. 実機でUIテストを流す

ビルドとテストを分ける。テストのコードを変えたら、`build-for-testing`からやり直す。

```sh
# ビルド（2と同じく、まずフラグなしで。止まったら確認してから付ける）
xcodebuild build-for-testing -project App.xcodeproj -scheme App \
  -destination "platform=iOS,id=$UDID" -derivedDataPath build

# テストだけ流す。TEST_RUNNER_の接頭辞を付けた環境変数は、接頭辞を外した名前でテストランナーに届く
rm -rf build/run.xcresult   # 同じパスがあると失敗する
TEST_RUNNER_BASE_URL=http://192.168.1.10:8080 xcodebuild test-without-building \
  -project App.xcodeproj -scheme App \
  -destination "platform=iOS,id=$UDID" -derivedDataPath build \
  -only-testing:AppUITests/SomeTests/testSomething \
  -resultBundlePath build/run.xcresult

# 添付（スクリーンショットなど）を取り出す
xcrun xcresulttool export attachments --path build/run.xcresult --output-path build/attachments
```

- 上の流れ（`build-for-testing`→`test-without-building`、`TEST_RUNNER_`での受け渡し、`-only-testing`、`xcresulttool export attachments`）は実機で通した。2件のUIテストで約1分【試した】。テスト側では`ProcessInfo.processInfo.environment["BASE_URL"]`で読む。
- `build-for-testing`は、`-destination 'generic/platform=iOS'`でも端末なしで通り、`build/Build/Products/`に`.xctestrun`ができる【試した】。ただし端末を指定しないので、端末の登録は確かめられない。
- 実機でUIテストを流すには、デベロッパモードと「UI Automation」が要る。端末はロックを解いておき、自動ロックで切れないようにする（`references/troubleshooting.md`）。
- シミュレータ向けに書いたUIテストは、ほぼそのまま実機で動いた。足したのは、URLを環境変数で渡すことと、実機だけで出る画面（HTTPの警告など）を閉じる処理【試した】。

## 4. archiveして.ipaを書き出す

```sh
xcodebuild archive -project App.xcodeproj -scheme App \
  -destination 'generic/platform=iOS' -archivePath build/App.xcarchive

xcodebuild -exportArchive -archivePath build/App.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export
```

XcodeでProduct → Archiveした直後なら、archiveはやり直さず、そのarchiveを`-archivePath`に渡す【試した：探して読むところまで】：

```sh
A=$(ls -td ~/Library/Developer/Xcode/Archives/*/*.xcarchive | head -1)   # いちばん新しいもの
/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties' "$A/Info.plist"  # Bundle ID、Team、SigningIdentity
```

名前に空白が入るので、`"$A"`のように引用符で囲む。Mac向けのarchiveも同じ場所に入るので、`CFBundleIdentifier`と`Architectures`で対象かを確かめる。

`ExportOptions.plist`の`method`は、何に使うかで選ぶ。名前は`xcodebuild -help`の「Available keys for -exportOptionsPlist」に出る新しいものを使う。Xcode 27で旧名を使うと`Command line name "development" is deprecated. Use "debugging" instead.`と出る（書き出しは通る）【試した】。

| 何に使うか | `method` | 旧名 | 入れられる端末 | 要るもの |
|---|---|---|---|---|
| 自分やチームの登録済みの端末で試す | `debugging` | `development` | プロファイルに入った端末 | 開発用の証明書とプロファイル。ワイルドカードで足りることが多い |
| 登録済みの端末のテスターに配る | `release-testing` | `ad-hoc` | プロファイルに入った端末 | 配布用の証明書と、Ad Hoc用のプロファイル |
| TestFlight・App Store | `app-store-connect` | `app-store` | TestFlightから | 配布用の証明書と、App Store用のプロファイル。App Store Connectのアプリの登録 |

- `debugging`は、archiveのときと同じ開発用のプロファイルで、`-allowProvisioningUpdates`なしで書き出せた（約2秒）【試した】。「ipa作って」の多くはこれで足りる。
- `release-testing`・`app-store-connect`は、そのBundle IDの配布用のプロファイルが手元になければ`No profiles for '<Bundle ID>' were found`で止まる【試した】。作るには`-allowProvisioningUpdates`が要り、ポータルが変わるので、ユーザーに確認してから。
- `.ipa`の中身は`unzip -l build/export/App.ipa`、使われた証明書とプロファイルは`build/export/DistributionSummary.plist`で確かめられる【試した】。
- plistの雛形、TestFlightへのアップロード、XcodeのOrganizerから書き出す方法、手動署名のときの注意は`references/export-options.md`。
- 以前の無料のPersonal Team向けのやり方（`.xcarchive`の`.app`を`Payload/`に入れてzipする）は要らない。有料のチームなら`-exportArchive`で書き出す。

## 5. よくある問題

詳しくは`references/troubleshooting.md`。要点だけ：

| 見え方 | まずすること |
|---|---|
| `No profiles for '<Bundle ID>' were found … pass -allowProvisioningUpdates` | プロファイル（場合によりApp ID）を作る必要がある。何が作られるかを添えて、ユーザーに確認する |
| ログに`DVTDeveloperAccountManager: Failed to load credentials … Invalid credentials in keychain` | 署名とビルドが通っていれば気にしなくてよい【試した】。ポータルとのやりとりで失敗するなら、Xcodeの設定＞Accountsでサインインし直してもらう |
| `codesign`のところで止まって進まない | Macの画面にキーチェーンの許可のダイアログが出ていないか、ユーザーに見てもらう。こちらで`security`を使って解決しない |
| インストールや起動、UIテストが端末のロックで失敗する | ユーザーにロックを解いてもらう |
| `developerModeStatus`が`enabled`でない | 設定＞プライバシーとセキュリティ＞デベロッパモード（再起動が要る） |
| UIテストが端末側の許可で始まらない | 設定＞デベロッパ＞UI Automationをオン |
| `… is Xcode managed, but signing settings require a manually managed profile` | 手動署名の書き出しにXcode管理のプロファイルを指定している。自動署名（`signingStyle: automatic`）にする【試した】 |

## 6. Safari Web Extensionのとき

拡張の有効化（iPhone・iPad・Mac）、UIテストで拡張をオンにする方法、iOS 27でHTTPのページを開くと毎回出る「この接続は安全ではありません」の警告の扱い、ログの見方は`references/safari-web-extension.md`。

## 参照ファイル

| ファイル | 読むとき |
|---|---|
| `references/signing-config.md` | ローカルのxcconfigで署名を切り替える、XcodeGenの`project.yml`を書く・直す |
| `references/export-options.md` | `ExportOptions.plist`を書く、Ad Hoc・TestFlightに出す、Organizerで書き出す |
| `references/safari-web-extension.md` | Safari Web Extensionを実機で動かす・テストする |
| `references/troubleshooting.md` | 署名・インストール・テストが止まった |
| `scripts/show-signing.sh` | 全ターゲットの署名の設定を一覧にする |
| `scripts/list-profiles.py` | 手元のプロファイルと、端末が含まれるかを見る |
