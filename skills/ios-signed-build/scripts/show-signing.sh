#!/bin/sh
# ターゲットごとの署名の設定（CODE_SIGN_STYLE・CODE_SIGN_IDENTITY・DEVELOPMENT_TEAM）とBundle IDを一覧にする。
# xcodebuild -showBuildSettingsは設定を読むだけで、ビルドも署名もせず、Developerポータルにもつながない。
#
# 使い方:
#   show-signing.sh                                   # カレントにある.xcodeprojの全ターゲット（-sdk iphoneos）
#   show-signing.sh -project App.xcodeproj -alltargets -sdk iphoneos
#   show-signing.sh -workspace App.xcworkspace -scheme App -destination 'generic/platform=iOS'
# 引数はそのままxcodebuild -showBuildSettingsに渡す。
set -eu

if [ "$#" -eq 0 ]; then
  set -- *.xcodeproj
  if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
    echo "カレントに.xcodeprojが1つだけある場所で実行するか、-project／-workspaceを渡す" >&2
    exit 64
  fi
  set -- -project "$1" -alltargets -sdk iphoneos
fi

xcodebuild -showBuildSettings "$@" 2>/dev/null | awk '
  function flush() {
    if (target != "" && !(target in seen)) {
      seen[target] = 1
      printf "%-32s %-18s %-10s %-20s %-12s %s\n", target, (sdk == "" ? "-" : sdk),
        (style == "" ? "(none)" : style), (identity == "" ? "(none)" : identity),
        (team == "" ? "(none)" : team), (bundle == "" ? "-" : bundle)
    }
    style = identity = team = bundle = sdk = ""
  }
  BEGIN { printf "%-32s %-18s %-10s %-20s %-12s %s\n", "TARGET", "SDK", "STYLE", "IDENTITY", "TEAM", "BUNDLE_ID" }
  /^Build settings for action [a-z]+ and target / { flush(); target = $NF; sub(/:$/, "", target); next }
  function value() { return substr($0, index($0, "=") + 2) }
  /^ +CODE_SIGN_STYLE = /           { style = value() }
  /^ +CODE_SIGN_IDENTITY = /        { identity = value() }
  /^ +DEVELOPMENT_TEAM = /          { team = value() }
  /^ +PRODUCT_BUNDLE_IDENTIFIER = / { bundle = value() }
  /^ +SDK_NAME = /                  { sdk = value() }
  END { flush() }
'
