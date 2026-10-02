#!/usr/bin/env python3
"""手元のプロビジョニングプロファイル（ファイル）を一覧にする。

使い方:
    list-profiles.py                      # すべて
    list-profiles.py <Bundle ID>          # そのBundle IDに効くもの（完全一致とワイルドカード）だけ
    list-profiles.py <Bundle ID> <UDID>   # 加えて、その端末が含まれるかを出す

プロファイルのファイルからplistの部分を取り出して読むだけで、キーチェーンは読まず、
Developerポータルにもつながない。証明書（DeveloperCertificates）と端末の一覧の中身は出さない。

種類の見分け方（Appleの公式の区分ではなく、中身からの推定）:
    development：端末の一覧あり、get-task-allow = true（xcodebuildのmethodではdebugging）。macOSは端末の一覧があればこれ
    ad-hoc：端末の一覧あり、get-task-allow = false（methodではrelease-testing）。iOS系だけ
    app-store：端末の一覧なし、ProvisionsAllDevicesなし（methodではapp-store-connect）
    enterprise：ProvisionsAllDevices = true（macOSではdeveloper-id）
macOSのプロファイルは、App IDのキーがcom.apple.application-identifierになる。
"""

import datetime
import pathlib
import plistlib
import sys

DIRS = [
    pathlib.Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",  # Xcode 16以降
    pathlib.Path.home() / "Library/MobileDevice/Provisioning Profiles",  # それより前
]


def load(path):
    raw = path.read_bytes()
    start = raw.find(b"<?xml")
    end = raw.find(b"</plist>")
    if start < 0 or end < 0:
        return None
    return plistlib.loads(raw[start : end + len(b"</plist>")])


def is_mac(p):
    return "OSX" in p.get("Platform", [])


def app_id_of(p):
    ent = p.get("Entitlements", {})
    return ent.get("application-identifier") or ent.get("com.apple.application-identifier", "")


def kind(p):
    ent = p.get("Entitlements", {})
    if p.get("ProvisionsAllDevices"):
        return "developer-id" if is_mac(p) else "enterprise"
    if p.get("ProvisionedDevices"):
        # macOSの開発用プロファイルはget-task-allowを持たない（macOSにad-hocの区分はない）
        if is_mac(p):
            return "development"
        return "development" if ent.get("get-task-allow") else "ad-hoc"
    return "app-store"


def covers(app_id, bundle_id):
    # app_idは「<Team ID>.<Bundle ID>」か「<Team ID>.<接頭辞>*」
    _, _, pattern = app_id.partition(".")
    if pattern.endswith("*"):
        return bundle_id.startswith(pattern[:-1])
    return pattern == bundle_id


def main():
    bundle_id = sys.argv[1] if len(sys.argv) > 1 else None
    udid = sys.argv[2] if len(sys.argv) > 2 else None
    now = datetime.datetime.now(datetime.timezone.utc)
    rows = []
    for d in DIRS:
        if not d.is_dir():
            continue
        for f in sorted(d.iterdir()):
            if f.suffix not in (".mobileprovision", ".provisionprofile"):
                continue
            p = load(f)
            if p is None:
                continue
            app_id = app_id_of(p)
            if bundle_id and not covers(app_id, bundle_id):
                continue
            exp = p.get("ExpirationDate")
            if exp is not None and exp.tzinfo is None:
                exp = exp.replace(tzinfo=datetime.timezone.utc)
            row = {
                "name": p.get("Name", "?"),
                "kind": kind(p),
                "platform": ",".join(p.get("Platform", [])),
                "app_id": app_id,
                "team": ",".join(p.get("TeamIdentifier", [])),
                "devices": len(p.get("ProvisionedDevices", [])),
                "expires": exp.date().isoformat() if exp else "?",
                "expired": bool(exp and exp < now),
                "xcode_managed": bool(p.get("IsXcodeManaged")),
                "uuid": p.get("UUID", f.stem),
            }
            if udid:
                row["has_udid"] = udid in p.get("ProvisionedDevices", []) or bool(p.get("ProvisionsAllDevices"))
            rows.append(row)

    if not rows:
        print("該当するプロファイルが手元にない" + (f"（{bundle_id}）" if bundle_id else ""))
        return 1
    for r in rows:
        flags = []
        if r["expired"]:
            flags.append("期限切れ")
        flags.append("Xcode管理" if r["xcode_managed"] else "手動管理")
        if udid:
            flags.append("端末あり" if r["has_udid"] else "端末なし")
        print(f'{r["kind"]:<12} {r["expires"]}  {r["app_id"]:<48} devices={r["devices"]:<3} '
              f'{" ".join(flags)}  "{r["name"]}"  {r["uuid"]}')
    return 0


if __name__ == "__main__":
    sys.exit(main())
