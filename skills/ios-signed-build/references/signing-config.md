# 署名の設定（xcconfig・XcodeGen）

印の意味はSKILL.mdと同じ（【試した】は2026-10-02、Xcode 27.0、XcodeGen 2.44.1で通したもの、【資料】は試していないもの）。

## 目次

1. 基本の値
2. Team IDをコミットしない：ローカルのxcconfigで切り替える
3. XcodeGenを使うとき
4. Xcodeで作ったプロジェクト（XcodeGenなし）のとき
5. 値を確かめる
6. コマンドラインで一度だけ差し込む

## 1. 基本の値

| 設定 | 値 | 備考 |
|---|---|---|
| `CODE_SIGN_STYLE` | `Automatic` | Xcodeが手元の証明書とプロファイルから選ぶ。`xcodebuild`がポータルで作るのは`-allowProvisioningUpdates`を付けたときだけ。XcodeでRunしたときは、Xcodeが自分でポータルにつないで作ることがある【資料】 |
| `DEVELOPMENT_TEAM` | Team ID（10文字） | 全ターゲットに同じ値 |
| `CODE_SIGN_IDENTITY` | `Apple Development` | 旧名は`iPhone Developer`。自動署名なら旧名でも`Apple Development`の証明書が選ばれた【試した】 |
| `PRODUCT_BUNDLE_IDENTIFIER` | 例：`com.example.App` | 拡張は`com.example.App.Extension`のように、アプリのIDで始める【資料】。UIテストは`com.example.App.UITests`などでよい |

- 特別なcapabilityのないアプリは、チームのワイルドカードのプロファイル（App IDが`<Team ID>.*`）で、アプリ・Safari Web Extension・UIテストのランナーのすべてが署名された。新しいApp IDは登録されなかった【試した】。
- App Groups、Push通知、iCloud、Associated Domainsなど、明示的なApp IDが要るcapabilityを足すと、`-allowProvisioningUpdates`のときにXcodeがApp IDを登録し、そのIDのプロファイルを作る【資料】。ポータルが変わるので、ユーザーに確認してから。
- Bundle IDの頭は、ほかのチームに登録済みのIDと重なると使えない。試作では、本番のIDと重ならない頭（`com.example.spike`など）にしておくと、両方を同じ端末に入れておける。

## 2. Team IDをコミットしない：ローカルのxcconfigで切り替える

ねらい：リポジトリには「チームなし（ad-hoc署名。シミュレータとMacのローカル実行用）」で入れておき、実機に入れる人だけが、コミットしないファイルに2行を書く。

`Config/Signing.xcconfig`（コミットする）：

```text
// 手元で変えるのは、Signing.local.xcconfig（コミットしない）に書く次の2つだけ
// Team ID（10文字）。空ならチームなしのad-hoc署名
APP_DEVELOPMENT_TEAM =
// Bundle IDの頭の部分
APP_BUNDLE_ID_PREFIX = com.example

// ---- ここから下は上の2つから決まる ----
// APP_DEVELOPMENT_TEAMが空なら、APP_CODE_SIGN_STYLE_（末尾が_の名前）の値になる。
// 空でなければAPP_CODE_SIGN_STYLE_<Team ID>という定義のない名前になり、:default=の値になる
APP_CODE_SIGN_STYLE_ = Manual
APP_CODE_SIGN_IDENTITY_ = -
APP_CODE_SIGN_STYLE = $(APP_CODE_SIGN_STYLE_$(APP_DEVELOPMENT_TEAM):default=Automatic)
APP_CODE_SIGN_IDENTITY = $(APP_CODE_SIGN_IDENTITY_$(APP_DEVELOPMENT_TEAM):default=Apple Development)

// 最後に読む。ここに書いた値が上のどれよりも優先する
#include? "Signing.local.xcconfig"
```

`Config/Signing.local.xcconfig`（`.gitignore`に入れる。`Signing.local.xcconfig.example`を置いておくと親切）：

```text
APP_DEVELOPMENT_TEAM = ABCDE12345
APP_BUNDLE_ID_PREFIX = com.example.yourname
```

各ターゲットの設定（ターゲットの階層に明示する）：

```text
CODE_SIGN_STYLE = $(APP_CODE_SIGN_STYLE)
CODE_SIGN_IDENTITY = $(APP_CODE_SIGN_IDENTITY)
DEVELOPMENT_TEAM = $(APP_DEVELOPMENT_TEAM)
PRODUCT_BUNDLE_IDENTIFIER = $(APP_BUNDLE_ID_PREFIX).App
```

- ローカルのファイルがあれば全ターゲットが`Automatic`・`Apple Development`・そのチームに、なければ`Manual`・`-`（ad-hoc）・チームなしになった【試した】。
- xcconfigはビルドのたびに読まれる。ローカルのファイルを書き換えても、`xcodegen generate`のやり直しは要らなかった（`-showBuildSettings`の値がすぐ変わった）【試した】。
- `APP_`の部分は、プロジェクトに固有の接頭辞にする（ほかの設定と名前がぶつからないように）。
- ターゲットの階層に明示するのは、ターゲットの階層の値がプロジェクトの階層（`configFiles`で読んだxcconfig）より強いため。XcodeGenのプリセットや、XcodeのSigning & Capabilitiesの画面が書いた値に負けないようにする。

## 3. XcodeGenを使うとき

### プリセットが`CODE_SIGN_IDENTITY`を上書きする

XcodeGenは、iOSアプリのターゲット（`type: application`、`platform: iOS`）にだけ、プリセット`SettingPresets/Product_Platform/application_iOS.yml`の`CODE_SIGN_IDENTITY: iPhone Developer`をターゲットの階層で書く【試した。brewのXcodeGen 2.44.1の`share/xcodegen/SettingPresets/`で確かめた】。拡張・UIテスト・macOSのターゲットには書かない。

| 形 | 結果 |
|---|---|
| ローカルのxcconfig（`#include?`の先）にだけ`CODE_SIGN_IDENTITY = Apple Development`を書いた | アプリのターゲットは`iPhone Developer`のまま。xcconfigの値は効かなかった【試した】 |
| プロジェクトに読み込むxcconfigの本体に`CODE_SIGN_IDENTITY`がある | XcodeGenはプリセットを書かなかった（include先は見ない）【別の作業の記録（XcodeGen 2.44.1）より。ここでは試していない】。キーを消したりローカルに移したりすると壊れるので、これには頼らない |
| `settingGroups`で全ターゲットに明示した（下の形） | 全ターゲットが`Apple Development`になった【試した】 |

### `project.yml`の書き方

署名に関わるところだけを書いた（`info`や`deploymentTarget`などは省いた）。この形とxcconfigの例をそのまま使ったプロジェクトで、archive・書き出し・`build-for-testing`まで通った【試した】。

```yaml
configFiles:
  Debug: Config/Signing.xcconfig
  Release: Config/Signing.xcconfig
settingGroups:
  # XcodeGenのプリセット（iOSアプリのCODE_SIGN_IDENTITY = iPhone Developer）に負けないよう、ターゲットごとに明示する
  signing:
    CODE_SIGN_STYLE: $(APP_CODE_SIGN_STYLE)
    CODE_SIGN_IDENTITY: $(APP_CODE_SIGN_IDENTITY)
    DEVELOPMENT_TEAM: $(APP_DEVELOPMENT_TEAM)
targets:
  App:
    type: application
    platform: iOS
    sources: [App]
    settings:
      groups: [signing]
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(APP_BUNDLE_ID_PREFIX).App
  AppUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [UITests]
    dependencies:
      - target: App
    settings:
      groups: [signing]
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(APP_BUNDLE_ID_PREFIX).App.UITests
        GENERATE_INFOPLIST_FILE: YES
```

- 拡張のターゲットにも`groups: [signing]`を付ける。
- `settingGroups`を定義しただけで、ターゲットの`settings.groups`に入れ忘れると効かない（プリセットのままになる）【試した】。
- XcodeGenは、ビルド設定から`TargetAttributes`の`DevelopmentTeam`も作り、そこには`$(APP_DEVELOPMENT_TEAM)`のような参照がそのまま入る。`xcodebuild`はビルド設定を使うので影響はない【試した】。XcodeのSigning & Capabilitiesの画面での見え方は確かめていない。
- `project.yml`を変えたら`xcodegen generate`。XcodeのSigning & Capabilitiesの画面で変えた値は、生成のたびに消える。
- `.xcodeproj`をコミットしない運用なら、`.gitignore`に入れる。

## 4. Xcodeで作ったプロジェクト（XcodeGenなし）のとき

【資料。この形では試していない】

- XcodeのSigning & Capabilitiesの画面でチームを選ぶと、ターゲットの階層に`DEVELOPMENT_TEAM`が書かれ、`project.pbxproj`に入る。そのままでよいプロジェクト（個人のリポジトリなど）は、そのままでよい。
- Team IDをコミットしたくないときは、2のxcconfigを、プロジェクトの「Configurations」でターゲットの階層（またはプロジェクトの階層）に割り当て、ターゲットの階層に書かれた`DEVELOPMENT_TEAM`を消すか`$(APP_DEVELOPMENT_TEAM)`にする。ターゲットの階層の値が残っていると、xcconfigより強いので効かない。
- 変えた後は、5の方法で全ターゲットの値を確かめる。

## 5. 値を確かめる

```sh
sh <このスキルのディレクトリ>/scripts/show-signing.sh -project App.xcodeproj -alltargets -sdk iphoneos
```

または、ターゲットごとに：

```sh
xcodebuild -project App.xcodeproj -target App -sdk iphoneos -showBuildSettings 2>/dev/null \
  | grep -E '^\s+(PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM|CODE_SIGN_STYLE|CODE_SIGN_IDENTITY) ='
```

どちらも設定を読むだけで、ビルドも署名もしない【試した】。`-sdk iphoneos`を付けるのは、シミュレータ向けと実機向けで値を分けているプロジェクトがあるため。

## 6. コマンドラインで一度だけ差し込む

```sh
xcodebuild archive -project App.xcodeproj -scheme App \
  -destination 'generic/platform=iOS' -archivePath build/App.xcarchive \
  DEVELOPMENT_TEAM=ABCDE12345
```

- ターゲットが`CODE_SIGN_STYLE = Automatic`でチームなしのプロジェクトに、コマンドラインでチームを渡してarchiveが通った【試した】。チームを渡さないと`Signing for "App" requires a development team. Select a development team in the Signing & Capabilities editor.`で止まった【試した】。
- コマンドラインの値はすべてのターゲット（Swift PackageやCocoaPodsのターゲットを含む）に効く。`DEVELOPMENT_TEAM`は害がないことが多いが、`CODE_SIGN_STYLE=Manual`や`PROVISIONING_PROFILE_SPECIFIER=…`をコマンドラインで渡すと、署名しないはずのターゲットまで巻き込んで失敗しやすい【資料】。手動署名にしたいときは、ターゲットの設定かExportOptions.plistで指定する。
